# adapted from http://gis.stackexchange.com/questions/28583/gdal-perform-simple-least-cost-path-analysis
# with documentation from http://scikit-image.org/docs/dev/api/skimage.graph.html?highlight=cost#skimage.graph.MCP.find_costs
import sys, getopt, gdal, osr
from skimage.graph import MCP
import numpy as np


def usage():
    print('Usage: '+sys.argv[0]+' [option...]' )
    print('\nOPTIONS\n')
    print('-h [--help] - Display this guide')
    print('-i [--input] <input file path> - Path to input cost raster')
    print('-o [--output] <output file path> - Path to save output to')
    print('-x <x coordinate> - X coordinate of the starting point (in the CRS of the input raster)')
    print('-y <y coordinate> - Y coordinate of the starting point (in the CRS of the input raster)')
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

def createCostSurface(CostSurfacefn,costSurfaceArray,startCoord):

    # coordinates to array index
    startCoordX = startCoord[0]
    startCoordY = startCoord[1]
    startIndexX,startIndexY = coord2pixelOffset(CostSurfacefn,startCoordX,startCoordY)

    # create cost surface
    graph = MCP(costSurfaceArray,fully_connected=False)
    fullCosts, costTraces = graph.find_costs([(startIndexY,startIndexX)])
    return fullCosts

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

#def main(CostSurfacefn,outputPathfn,startCoord):
def main(argv):
    try:
        opts, args = getopt.getopt(argv, "hi:o:x:y:",["help","input=","output="])
    except getopt.GetoptError:
        usage()
        sys.exit(2)

    # check required flags
    flags = [i[0] for i in opts]
    if set(["-i","--input"]).isdisjoint(flags):
        usage()
        print('\n<< Hint: Missing input file parameter >>\n')
        sys.exit(2)
    if set(["-o","--output"]).isdisjoint(flags):
        usage()
        print('\n<< Hint: Missing output file parameter >>\n')
        sys.exit(2)
    if '-x' not in flags:
        usage()
        print('\n<< Hint: Missing X coordinate parameter >>\n')
        sys.exit(2)
    if '-y' not in flags:
        usage()
        print('\n<< Hint: Missing Y coordinate parameter >>\n')
        sys.exit(2)

    # declarations
    CostSurfacefn = ''
    outputPathfn = ''
    xCoord = float()
    yCoord = float()

    # parse options
    for opt, arg in opts:
        if opt in ("-h", "--help"):
            usage()
            sys.exit()
        elif opt in ("-i", "--input"):
            CostSurfacefn = arg
        elif opt in ("-o", "--output"):
            outputPathfn = arg
        elif opt == "-x":
            xCoord = float(arg)
        elif opt == "-y":
            yCoord = float(arg)

    startCoord = (xCoord,yCoord)
    costSurfaceArray = raster2array(CostSurfacefn) # creates array from cost surface raster
    costSurface = createCostSurface(CostSurfacefn,costSurfaceArray,startCoord) # creates path array
    array2raster(outputPathfn,CostSurfacefn,costSurface) # converts path array to raster


if __name__ == "__main__":
    main(sys.argv[1:])
