# -*- coding: mbcs -*-
#
# Abaqus/CAE Release 2023.HF4 replay file
# Internal Version: 2023_07_21-20.45.57 RELr425 183702
# Run by nguyenb5 on Thu Feb 13 17:40:11 2025
#

# from driverUtils import executeOnCaeGraphicsStartup
# executeOnCaeGraphicsStartup()
#: Abaqus Warning: Unknown keyword (current_os) in environment file.
#: Abaqus Warning: Please check spelling of the environment variable names.
#:                 Unknown keyword "keywordname" can be removed using "del keywordname"
#:                 at the end of environment file.
#: Executing "onCaeGraphicsStartup()" in the site directory ...
from abaqus import *
from abaqusConstants import *
session.Viewport(name='Viewport: 1', origin=(0.0, 0.0), width=234.03645324707, 
    height=121.741897583008)
session.viewports['Viewport: 1'].makeCurrent()
session.viewports['Viewport: 1'].maximize()
from caeModules import *
from driverUtils import executeOnCaeStartup
executeOnCaeStartup()
#: Abaqus Warning: Unknown keyword (current_os) in environment file.
#: Abaqus Warning: Please check spelling of the environment variable names.
#:                 Unknown keyword "keywordname" can be removed using "del keywordname"
#:                 at the end of environment file.
openMdb('elastic_hole_plate_3D.cae')
#: The model database "C:\LocalUserData\User-data\nguyenb5\COMSOL-Hydrogen-Diffusion-Simulation\elastic_plate_3D\elastic_hole_plate_3D.cae" has been opened.
session.viewports['Viewport: 1'].setValues(displayedObject=None)
session.viewports['Viewport: 1'].partDisplay.geometryOptions.setValues(
    referenceRepresentation=ON)
p = mdb.models['elastic_plate_2D'].parts['elastic_hole_plate']
session.viewports['Viewport: 1'].setValues(displayedObject=p)
p1 = mdb.models['elastic_plate_3D'].parts['elastic-hold-plate']
session.viewports['Viewport: 1'].setValues(displayedObject=p1)
p1 = mdb.models['elastic_plate_2D'].parts['elastic_hole_plate']
session.viewports['Viewport: 1'].setValues(displayedObject=p1)
session.viewports['Viewport: 1'].view.setValues(nearPlane=0.137616, 
    farPlane=0.182609, width=0.124189, height=0.0576044, 
    viewOffsetX=0.00536536, viewOffsetY=0.0016546)
p1 = mdb.models['elastic_plate_3D'].parts['elastic-hold-plate']
session.viewports['Viewport: 1'].setValues(displayedObject=p1)
#: 
#: Point 1: 0., 60.E-03, 2.E-03  Point 2: 53.E-03, 60.E-03, 2.E-03
#:    Distance: 53.E-03  Components: 53.E-03, 0., 0.
#: 
#: Point 1: 53.E-03, 0., 2.E-03  Point 2: 53.E-03, 60.E-03, 2.E-03
#:    Distance: 60.E-03  Components: 0., 60.E-03, 0.
#: 
#: Point 1: 0., 0., 2.E-03  Point 2: 4.E-03, 0., 2.E-03
#:    Distance: 4.E-03  Components: 4.E-03, 0., 0.
