# adapted from http://gis.stackexchange.com/questions/28583/gdal-perform-simple-least-cost-path-analysis
# with documentation from http://scikit-image.org/docs/dev/api/skimage.graph.html?highlight=cost#skimage.graph.MCP.find_costs
import sys, getopt, gdal, osr, os, psycopg2
from skimage.graph import MCP
from skimage.morphology import disk
from scipy.ndimage.filters import minimum_filter
import numpy as np


def usage():
    print('\n')
    print('Usage: '+sys.argv[0]+' [options...] [all] [id id ...]' )
    print('\nOPTIONS\n')
    print('[--help] - Display this guide')
    print('[--debug] <output directory> - Debug mode (saves intermediate files to output directory)')
    print('-f [--input] <input file path> - Path to input cost raster')
    print('-d [--database] <database name> - Name of database')
    print('[-u] [--user] <username> - Database username')
    print('[-h] [--host] <host address> - Database host address')
    print('[-p] [--pass] <password> - Database password')
    print('[-s] [--schema] <schema name> - Database schema')
    print('-t [--table] <table name> - Database table name')
    print('-r [--radius] <radius> - Search radius')
    print('[-w] [--where] <SQL> - Valid SQL where clause (without WHERE at the start)')
    print('\n')

def raster2array(rasterfn):
    raster = gdal.Open(rasterfn)
    band = raster.GetRasterBand(1)
    array = band.ReadAsArray().astype(np.uint16)
    return array

def coord2pixelOffset(rasterfn,x,y):
    raster = gdal.Open(rasterfn)
    geotransform = raster.GetGeoTransform()
    originX = geotransform[0]
    originY = geotransform[3]
    pixelWidth = geotransform[1]
    pixelHeight = geotransform[5]
    xOffset = int((x - originX)/pixelWidth)
    yOffset = int((y - originY)/pixelHeight)
    return xOffset,yOffset

def createLCD(costSurface,costSurfaceArray,startCoord):

    # coordinates to array index
    startCoordX = startCoord[0]
    startCoordY = startCoord[1]
    startIndexX,startIndexY = coord2pixelOffset(costSurface,startCoordX,startCoordY)

    # create cost surface
    graph = MCP(costSurfaceArray,fully_connected=False)
    fullCosts, costTraces = graph.find_costs([(startIndexY,startIndexX)])
    return fullCosts

def costMinArray(array,radius):
    return minimum_filter(
        array,
        footprint=disk(int(radius)),
        mode='nearest'
    )

def array2raster(newRasterfn,rasterfn,array):
    raster = gdal.Open(rasterfn)
    geotransform = raster.GetGeoTransform()
    originX = geotransform[0]
    originY = geotransform[3]
    pixelWidth = geotransform[1]
    pixelHeight = geotransform[5]
    cols = array.shape[1]
    rows = array.shape[0]

    driver = gdal.GetDriverByName('GTiff')
    outRaster = driver.Create(newRasterfn, cols, rows, eType=gdal.GDT_UInt16)
    outRaster.SetGeoTransform((originX, pixelWidth, 0, originY, 0, pixelHeight))
    outband = outRaster.GetRasterBand(1)
    outband.WriteArray(array)
    outRasterSRS = osr.SpatialReference()
    outRasterSRS.ImportFromWkt(raster.GetProjectionRef())
    outRaster.SetProjection(outRasterSRS.ExportToWkt())
    outband.FlushCache()

def main(argv):
    try:
        opts, args = getopt.getopt(
            argv,
            "f:d:u:h:p:s:t:r:w:",
            ["help","debug=","input=","database=","user=","host=","pass=","schema=","table=","radius=","where="]
        )
    except getopt.GetoptError:
        print("Bad command line option")
        usage()
        sys.exit(2)

    # declarations
    debug = False
    debugPath = ''
    database = ''
    user=''
    host=''
    password=''
    schema=''
    table=''
    radius=int()
    where=''

    costSurfaceRaster = ''
    outputPathfn = ''
    xCoord = float()
    yCoord = float()

    # parse options
    for opt, arg in opts:
        if opt == "--help":
            usage()
            sys.exit()
        elif opt == "--debug":
            if not os.path.isdir(arg):
                print("Debug directory " + arg + " does not exist")
            else:
                debugPath = arg
                debug = True
        elif opt in ("-f", "--input"):
            if not os.path.isfile(arg):
                print("Input file " + arg + " does not exist")
                sys.exit()
            else:
                costSurfaceRaster = arg
        elif opt in ("-d", "--database"):
            database = arg
        elif opt in ("-u", "--user"):
            user = arg
        elif opt in ("-h", "--host"):
            host = arg
        elif opt in ("-p", "--pass"):
            password = arg
        elif opt in ("-s", "--schema"):
            schema = arg
        elif opt in ("-t", "--table"):
            table = arg
        elif opt in ("-r", "--radius"):
            if str.isdigit(arg):
                radius = arg
            else:
                print("Radius " + arg + "is not a number")
        elif opt in ("-w", "--where"):
            where = arg

    # check required flags
    flags = [i[0] for i in opts]
    if set(["-f","--input"]).isdisjoint(flags):
        usage()
        print('\n<< Hint: Missing input file parameter >>\n')
        sys.exit(2)
    if set(["-d","--database"]).isdisjoint(flags):
        usage()
        print('\n<< Hint: Missing database parameter >>\n')
        sys.exit(2)
    if set(["-t","--table"]).isdisjoint(flags):
        usage()
        print('\n<< Hint: Missing table parameter >>\n')
        sys.exit(2)
    if set(["-r","--radius"]).isdisjoint(flags):
        usage()
        print('\n<< Hint: Missing radius parameter >>\n')
        sys.exit(2)

    # connect to db
    dbConnectionString = "dbname=" + database
    if not user == '':
        dbConnectionString += " user=" + user
    if not host == '':
        dbConnectionString += " host=" + host
    if not password == '':
        dbConnectionString += " pass=" + password
    conn = psycopg2.connect(dbConnectionString)
    cur = conn.cursor()

    # query and retrieve features
    fullTableName = ''
    if not schema == '':
        fullTableName = '"' + schema + '".'
    fullTableName += '"' + table + '"'
    query = '   SELECT  id, \
                        ST_X(ST_StartPoint(geom)) AS x1, \
                        ST_Y(ST_StartPoint(geom)) AS y1, \
                        ST_X(ST_EndPoint(geom)) AS x2, \
                        ST_Y(ST_EndPoint(geom)) AS y2 \
                FROM    ' + fullTableName
    if not where == '':
        query += ' WHERE ' + where
    query += ' ORDER BY ST_X(ST_StartPoint(geom)), ST_Y(ST_StartPoint(geom)) '
    query += ';'
    cur.execute(query)

    # convert the input cost surface raster to an array
    costSurface = raster2array(costSurfaceRaster)

    # iterate over features and update crossing costs
    currentIndex = None
    currentLcd = None
    for record in cur:
        fid = record[0]
        coord1 = (record[1],record[2])
        coord2 = (record[3],record[4])
        index1 = coord2pixelOffset(costSurfaceRaster,record[1],record[2])
        index2 = coord2pixelOffset(costSurfaceRaster,record[3],record[4])

        # check if points are on a barrier, skip if so
        # if debug:
        #     print("origin/destination cost pixels")
        #     print(str(costSurface[index1]) + " " + str(costSurface[index2]))
        # if costSurface[index1] >= 999 or costSurface[index2] >= 999:
        #     print("Feature " + str(fid) + " is located on a barrier, skipping")
        #     continue

        # get least cost distances for both points
        if not currentIndex == index1:
            print("New source feature")
            currentIndex = index1
            currentLcd = createLCD(costSurfaceRaster,costSurface,coord1)
        lcd1 = currentLcd
        lcd2 = createLCD(costSurfaceRaster,costSurface,coord2)

        # get minimum existing distance
        minDistanceExist = np.amin(
            np.add(
                lcd1,
                lcd2
            )
        )

        # get minimum improved distance
        lcd1Improved = costMinArray(lcd1,radius)
        lcd2Improved = costMinArray(lcd2,radius)
        minDistanceImproved = np.amin(
            np.add(
                lcd1Improved,
                lcd2Improved,
                np.full_like(lcd1, 2 * radius)
            )
        )

        # write to db
        uCur = conn.cursor()
        update = '  UPDATE  ' + fullTableName + ' \
                    SET     cost_exist = %s, \
                            cost_improved = %s \
                    WHERE   id = %s;'
        print("Updating feature " + str(fid) + " with exist = " + str(minDistanceExist) + ", improved = " + str(minDistanceImproved))
        uCur.execute(update,(minDistanceExist,minDistanceImproved,fid))
        conn.commit()
        uCur.close()

        # write rasters if debug is set
        if debug:
            outFileExist1 = os.path.join(debugPath,"fid" + str(fid) + "_1exist.tif")
            outFileExist2 = os.path.join(debugPath,"fid" + str(fid) + "_2exist.tif")
            outFileImproved1 = os.path.join(debugPath,"fid" + str(fid) + "_1imprv.tif")
            outFileImproved2 = os.path.join(debugPath,"fid" + str(fid) + "_2imprv.tif")

            array2raster(outFileExist1, costSurfaceRaster, lcd1)
            array2raster(outFileExist2, costSurfaceRaster, lcd2)
            array2raster(outFileImproved1, costSurfaceRaster, lcd1Improved)
            array2raster(outFileImproved2, costSurfaceRaster, lcd2Improved)




    # startCoord = (xCoord,yCoord)
    # costSurfaceArray = raster2array(costSurface) # creates array from cost surface raster
    # costSurface = createLCD(costSurface,costSurfaceArray,startCoord) # creates path array
    # array2raster(outputPathfn,costSurface,costSurface) # converts path array to raster

    # close up shop
    cur.close()
    conn.close()

if __name__ == "__main__":
    main(sys.argv[1:])
