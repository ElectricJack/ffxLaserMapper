import com.fieldfx.math.*;
import com.fieldfx.serialize.*;
import java.util.List;


import hypermedia.net.*; // import UDP library
import processing.net.*; // import TCP library 

import oscP5.*;
import netP5.*;

OscP5    oscP5;
UDP      udp;        // UDP Listener
Client   etherdream;
//PeasyCam cam;

final String  fileName = "mapping.json";
final boolean log      = true;

Mapping         data      = new Mapping();
JSONSerializer  store     = null;
int             editMode  = 0;
EdgeList        activeEdgeList = new EdgeList();

// Control State
Vector2         hover;
Vector2         startDrag = new Vector2();
boolean         dragging;
boolean         mouseDown;
boolean         mouseUp;
boolean         wasMousePressed;
boolean         keyWasPressed;

boolean         laserMouse = false;
boolean         drawLaser = true;
int             currentEdgeList = 0; 
boolean         drawLaserAnimationPath = false;

final int       blankingPointRate = 2000;


float           time; // Used by animation
boolean         laserEnabled = false; // Used by animation


// tag edges
// select [tags]
// execute pattern with params


// Done:
	// Draw the laser path

	// Need to be able to playback motion of laser over a calibrated laser path. Hard-coded duration for the playback, option to stop/loop
	//   - Already prototyped loading the laser path
	//   - Need to be able to interpolate the path based on a function of the entire paths length.
	//     - On initialization calculate all edge lengths and store at the start of each vertex
	//     - To find a location in time t from 0-1, multiply by total path length, then keep subtracting edge lengths until you fall within an edge length

	// Need to be able to preview the path with the laser and align it to the geometry
	// Serialize the location of the laser path object
	// Set start index for the animation and length of animation

	// - Get the OSC playback time from that clip from resolume??
	//   - This would be ultimate sync system

	// - Separate edit mode for alignment (this way it doesn't get screwed up)

	// - Need to be able to set different point rendering speeds between paths

//------------------------------------------------
// Todo:

	// - Calculate next time to send data and wait.

  // - Need to change point speed for blanking at start/end
	// - Scan effects need to go all the way to the last point in the list
	// - Blank the laser before moving to the animated track location
	// - Make it so that you can't edit the laser path alignment points unless you are in the laser path mode


	// - Implement charging animation
	// Write some different laser animations

	// Need to be able to trigger different edges with effects from different OSC triggers   enable/disable for each edge/effect

	// Stretch:
	//  - Need the ability to trigger more than one laser loop path animation at a time




void setup()
{
	size(800,600,P3D);
  oscP5 = new OscP5(this,12000);
	udp   = new UDP( this, 7654 );
	store = new JSONSerializer(this);
	store.registerType(new Mapping());
	store.registerType(new EdgeList());
	store.registerType(new PointIndex());
	store.registerType(new Vector2());
	store.registerType(new LaserPath());

	//udp.log( true ); 		// <-- printout the connection activity
	udp.listen( true );

	loadData();
	if (!data.path.isLoaded())
		data.path.load(data.path.sourcePath);

	frameRate(30);
}

//int updateSampler=0;
void draw()
{
	colorMode(HSB,255);
	background(color(editMode*40,100,100));

	//updateSampler++;
	//if((updateSampler % 4) == 0)
	updateEtherDream();

  // Control logic
	mouseDown = !wasMousePressed && mousePressed;
	if (mouseDown) {
		println("startDrag");
		startDrag.set(mouseX, mouseY);
	}
	dragging = wasMousePressed && startDrag.sub(mouseX, mouseY).len() > 0;
	mouseUp  = wasMousePressed && !mousePressed && !dragging;
	wasMousePressed = mousePressed;

  data.path.draw();

	if      (editMode == 0) updateEditPoints();
	else if (editMode == 1) updateEditEdges();
	else if (editMode == 2) updatePlaceLaserPath();


	keyWasPressed = keyPressed;
}




void keyPressed()
{
	if      (key == '1') editMode = 0;
	else if (key == '2') editMode = 1;
	else if (key == '3') editMode = 2;
	else if (key == '4') editMode = 3;
	else if (key == '5') editMode = 4;
	else if (key == '6') editMode = 5;

	if(key == 'a') { drawLaserAnimationPath = !drawLaserAnimationPath; println("drawLaserAnimationPath: " + drawLaserAnimationPath); }
	if(key == 's') { laserMouse = !laserMouse; println("laserMouse: " + laserMouse); }
	if(key == 'd') { drawLaser = !drawLaser; println("drawLaser: " + drawLaser); } 

	if (keyCode == LEFT) ++currentEdgeList;
	if (keyCode == RIGHT) --currentEdgeList;

	int count = data.edgeLists.size();
	if(count > 0) {
		currentEdgeList = (currentEdgeList + count) % count;
		// println("count: "+count);
	}
}


void updatePlaceLaserPath()
{
	float   x = mouseX / (float)width;
	float   y = mouseY / (float)height;

	// Render all points on screen
	noStroke();
	updateHoverPoint();
	drawPoints();

	if (dragging && hover != null) {
		hover.set(x, y);
	}

	drawAllEdgeLists();
}





void scanPointOnPath()
{
  if (!laserEnabled)
    return;
    
  Vector2 at = data.path.getPositionAtTime(time);
  if (at != null) {
    fill(255,0,0);
    ellipse(at.x, at.y, 10,10);
    setColor(1,1,1);
    addPoint(at.x/width, at.y/height);
    addPoint(at.x/width, at.y/height);
    addPoint(at.x/width, at.y/height);
  }
}

void updateEditPoints()
{
	float   x = mouseX / (float)width;
	float   y = mouseY / (float)height;

	// Render all points on screen
	noStroke();
	updateHoverPoint();
	drawPoints();

	// Shift-click to delete
	if (mouseUp && keyPressed && keyCode == SHIFT)
	{
		removePoint(hover);
	}
	// Click to add points
	else if (mouseUp) {
		addPoint(new Vector2(x,y), true);
	}

	// Drag to move points
	else if (dragging && hover != null) {
		hover.set(x, y);
	}

	drawAllEdgeLists();
}

void updateEditEdges()
{
	// Render all points on screen
	noStroke();
	updateHoverPoint();
	drawPoints();

	if (mouseUp && hover != null) {
		PointIndex hoverIndex = indexOfPoint(hover);
		if (hoverIndex != null)
			activeEdgeList.loop.add(hoverIndex);
	}

	if (keyPressed && !keyWasPressed && keyCode == ENTER) {
    if (activeEdgeList.loop.size() > 1) {
  		data.edgeLists.add(activeEdgeList);
  		saveData();
    }
    activeEdgeList = new EdgeList();
	}

	if (keyPressed && !keyWasPressed && keyCode == BACKSPACE)
	{
		println("delete active edge");
		data.edgeLists.remove(currentEdgeList);
		activeEdgeList = new EdgeList();
		currentEdgeList = 0;
	}

	// Draw the active edge list
	stroke(255,0,0);
	drawEdgeList(activeEdgeList, true);

	drawAllEdgeLists();
}

void drawAllEdgeLists()
{
	stroke(200);
	for(int i=0; i<data.edgeLists.size(); ++i) {
		drawEdgeList(data.edgeLists.get(i), false);
	}
}

void drawEdgeList(EdgeList edgeList, boolean toMouse)
{
	if (edgeList == null)
		return;

  float   x = mouseX / (float)width;
  float   y = mouseY / (float)height;

  strokeWeight(1);
	int count = edgeList.loop.size();
	for(int i=0; i<count; ++i) {
		int fromIndex = edgeList.loop.get(i).index;
		if(fromIndex >= data.points.size()) continue;

		Vector2 from = data.points.get(fromIndex);
		Vector2 to   = null;

		if (i+1 < count) {
			int toIndex = edgeList.loop.get(i+1).index;
			if(toIndex >= data.points.size()) continue;

			to = data.points.get(toIndex);
		} else if (toMouse) {
			to = new Vector2(x,y);
		}

    if (to != null)
		  line(from.x*width, from.y*height, to.x*width, to.y*height);
	}
}

void updateHoverPoint()
{
	float   x = mouseX / (float)width;
	float   y = mouseY / (float)height;

	if (!dragging) {
		hover = findClosestPoint(x,y,30.0/width);
	}

	// Draw the hover
	if (hover != null) {
		fill(0);
		drawPoint(hover, 5);
	}
}

void drawPoints()
{
	fill(255);
	noStroke();
	float s = 2;
	for (int i=0; i<movablePoints.size(); ++i) {
		Vector2 point = movablePoints.get(i);
		drawPoint(point, s);
	}
}

void drawPoint(Vector2 point, float s)
{
	pushMatrix();
		translate(point.x * width, point.y * height);
		rect(-s/2,-s/2,s,s);
	popMatrix();
}


int laserEffectMode = 0;
void oscEvent(OscMessage theOscMessage) {
  
  if (theOscMessage.checkAddrPattern("/composition/layers/2/clips/1/transport/position")) {
  	float resolumeClipTime = theOscMessage.get(0).floatValue();
		//0.325 to 1.273
		time = map(resolumeClipTime, 0, 0.484, 0.325, 1.273);
    laserEnabled = resolumeClipTime < 0.484;
    //println(""+ time + " " + resolumeClipTime);
  }
  else if (theOscMessage.checkAddrPattern("/composition/layers/3/clips/1/transport/position"))
  {
  	//println("effect 0");
    laserEffectMode = 0;
  }
  else if (theOscMessage.checkAddrPattern("/composition/layers/3/clips/2/transport/position"))
  {
  	//println("effect 1");
    laserEffectMode = 1;
  }
  else if (theOscMessage.checkAddrPattern("/composition/layers/3/clips/3/transport/position"))
  {
  	//println("effect 2");
    laserEffectMode = 2;
  }
  else if (theOscMessage.checkAddrPattern("/composition/layers/3/clips/4/transport/position"))
  {
  	//println("effect 3");
    laserEffectMode = 3;
  }
}
