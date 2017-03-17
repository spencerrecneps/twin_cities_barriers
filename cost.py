# adapted from http://gis.stackexchange.com/questions/28583/gdal-perform-simple-least-cost-path-analysis
# with documentation from http://scikit-image.org/docs/dev/api/skimage.graph.html?highlight=cost#skimage.graph.MCP.find_costs
import gdal, osr
from skimage.graph import MCP
import numpy as np


def raster2array(rasterfn):
    raster = gdal.Open(rasterfn)
    band = raster.GetRasterBand(1)
    array = band.ReadAsArray()
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
    outRaster = driver.Create(newRasterfn, cols, rows, gdal.GDT_Byte)
    outRaster.SetGeoTransform((originX, pixelWidth, 0, originY, 0, pixelHeight))
    outband = outRaster.GetRasterBand(1)
    outband.WriteArray(array)
    outRasterSRS = osr.SpatialReference()
    outRasterSRS.ImportFromWkt(raster.GetProjectionRef())
    outRaster.SetProjection(outRasterSRS.ExportToWkt())
    outband.FlushCache()

def main(CostSurfacefn,outputPathfn,startCoord):
    costSurfaceArray = raster2array(CostSurfacefn) # creates array from cost surface raster
    costSurface = createCostSurface(CostSurfacefn,costSurfaceArray,startCoord) # creates path array
    array2raster(outputPathfn,CostSurfacefn,costSurface) # converts path array to raster


if __name__ == "__main__":
    CostSurfacefn = '/home/spencer/gis/tcbarriers/cost.tif'
    startCoord = (476706,4976282)
    outputPathfn = '/home/spencer/gis/tcbarriers/cost_surface.tif'
    main(CostSurfacefn,outputPathfn,startCoord)
