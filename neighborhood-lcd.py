# http://scikit-image.org/docs/dev/api/skimage.morphology.html#disk


import sys, getopt, gdal, osr
from skimage.graph import MCP
from scipy.ndimage.filters import minimum_filter
import numpy as np

a = np.array(  [[1,2,3,4,5],
                [6,7,8,9,10],
                [11,12,13,14,15],
                [16,17,18,19,20],
                [21,22,23,24,25]],dtype=np.uint16)

f = np.array(  [[False,True,False],
                [True,True,True],
                [False,True,False]],dtype=np.uint16)

minimum_filter(a,footprint=f,mode='nearest')

def usage():
    print('Usage: '+sys.argv[0]+' [option...]' )
    print('\nOPTIONS\n')
    print('-h [--help] - Display this guide')
    print('--c1 <cost raster file path> - Path to first cost raster')
    print('--c2 <cost raster file path> - Path to second cost raster')
    print('-o [--output] <output file path> - Path to save output to')
    print('\n')

def raster2array(rasterfn):
    raster = gdal.Open(rasterfn)
    band = raster.GetRasterBand(1)
    array = band.ReadAsArray().astype(uint16)
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
        opts, args = getopt.getopt(argv, "ho:",["help","c1=","c2="])
    except getopt.GetoptError:
        usage()
        sys.exit(2)

    # check required flags
    flags = [i[0] for i in opts]
    if set(["-o","--output"]).isdisjoint(flags):
        usage()
        print('\n<< Hint: Missing output file parameter >>\n')
        sys.exit(2)
    if '--c1' not in flags:
        usage()
        print('\n<< Hint: Missing cost raster input parameter >>\n')
        sys.exit(2)
    if '--c2' not in flags:
        usage()
        print('\n<< Hint: Missing cost raster input parameter >>\n')
        sys.exit(2)

    # declarations
    CostSurfaceA = ''
    CostSurfaceB = ''
    outputPathfn = ''

    # parse options
    for opt, arg in opts:
        if opt in ("-h", "--help"):
            usage()
            sys.exit()
        elif opt in ("-o", "--output"):
            outputPathfn = arg
        elif opt == "--c1":
            CostSurfaceA = arg
        elif opt == "--c2":
            CostSurfaceB = arg

    costSurfaceArrayA = raster2array(CostSurfaceA) # creates array from cost surface raster
    costSurfaceArrayB = raster2array(CostSurfaceB) # creates array from cost surface raster
    costSurface = createCostSurface(CostSurfacefn,costSurfaceArray,startCoord) # creates path array
    array2raster(outputPathfn,CostSurfacefn,costSurface) # converts path array to raster


if __name__ == "__main__":
    main(sys.argv[1:])
