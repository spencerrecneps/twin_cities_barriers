import sys, getopt, gdal, osr
from skimage.morphology import disk
from scipy.ndimage.filters import minimum_filter, maximum_filter
import numpy as np


def usage():
    print('Usage: '+sys.argv[0]+' [option...]' )
    print('\nOPTIONS\n')
    print('-h [--help] - Display this guide')
    print('--c1 <cost raster file path> - Path to first cost raster')
    print('--c2 <cost raster file path> - Path to second cost raster')
    print('-i [--improve] - Minimum improvement threshold')
    print('-r [--radius] - Search radius, given as number of pixels')
    print('-o [--output] <output file path> - Path to save output to')
    print('\n')


def raster2array(rasterfn):
    raster = gdal.Open(rasterfn)
    band = raster.GetRasterBand(1)
    array = band.ReadAsArray().astype(np.float32)
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


def costMinArray(array,radius):
    return minimum_filter(
        array,
        footprint=disk(radius),
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
        opts, args = getopt.getopt(argv, "ho:r:i:",["help","improve=","c1=","c2=","radius="])
    except getopt.GetoptError:
        usage()
        sys.exit(2)

    # declarations
    CostSurfaceA = ''
    CostSurfaceB = ''
    outputPathfn = ''
    inputRadius = int()
    improvementThreshold = int()

    # parse options
    for opt, arg in opts:
        if opt in ("-h", "--help"):
            usage()
            sys.exit()
        if opt in ("-i", "--improve"):
            if not str.isdigit(arg): #isinstance( arg, (int, long) ):
                print("Improvement threshold parameter requires an integer")
                usage()
                sys.exit(2)
            else:
                improvementThreshold = int(arg)
        elif opt in ("-o", "--output"):
            outputPathfn = arg
        elif opt in ("-r", "--radius"):
            if not str.isdigit(arg): #isinstance( arg, (int, long) ):
                print("Radius parameter requires an integer")
                usage()
                sys.exit(2)
            else:
                inputRadius = int(arg)
        elif opt == "--c1":
            CostSurfaceA = arg
        elif opt == "--c2":
            CostSurfaceB = arg

    # check required flags
    flags = [i[0] for i in opts]
    if set(["-o","--output"]).isdisjoint(flags):
        usage()
        print('\n<< Hint: Missing output file parameter >>\n')
        sys.exit(2)
    if set(["-i","--improve"]).isdisjoint(flags):
        usage()
        print('\n<< Hint: Missing improvement threshold parameter >>\n')
        sys.exit(2)
    if set(["-r","--radius"]).isdisjoint(flags):
        usage()
        print('\n<< Hint: Missing radius parameter >>\n')
        sys.exit(2)
    if '--c1' not in flags:
        usage()
        print('\n<< Hint: Missing cost raster input parameter >>\n')
        sys.exit(2)
    if '--c2' not in flags:
        usage()
        print('\n<< Hint: Missing cost raster input parameter >>\n')
        sys.exit(2)

    # create arrays from cost surface raster
    costSurfaceArrayA = raster2array(CostSurfaceA)
    costSurfaceArrayB = raster2array(CostSurfaceB)

    # get array of existing minimum cost
    existMinCostArray = np.add(costSurfaceArrayA,costSurfaceArrayB)

    # get shortest path cost
    existMinCost = np.amin(existMinCostArray)
    print("Minimum existing cost: " + str(existMinCost))

    # get improved minimum cost
    minCostArrayA = costMinArray(costSurfaceArrayA,inputRadius)
    minCostArrayB = costMinArray(costSurfaceArrayB,inputRadius)
    imprvMinCostArray = np.add(       # add constant equal to 2xradius to represent new connection
        minCostArrayA,
        minCostArrayB,
        np.full_like(minCostArrayA, 2 * inputRadius*30)
    )
    imprvMinCost = np.amin(imprvMinCostArray)
    print("Minimum improved cost: " + str(imprvMinCost))

    # compare improved to previous shortes path

    # get ratio of improved to existing
    #benefit = np.divide(imprvMinCostArray,existMinCostArray)
    # benefit = np.where(imprvMinCostArray < (existMinCost - improvementThreshold), existMinCost - imprvMinCostArray, np.nan)
    # benefit = np.where(imprvMinCostArray < (existMinCostArray - improvementThreshold), existMinCostArray - imprvMinCostArray, 0)
    benefit = np.where(
        imprvMinCostArray < np.full_like(minCostArrayA, existMinCost),
        np.full_like(minCostArrayA, existMinCost) - imprvMinCostArray, 
        0
    )

    # output new raster
    array2raster(outputPathfn,CostSurfaceA,benefit) # converts path array to raster


if __name__ == "__main__":
    main(sys.argv[1:])
