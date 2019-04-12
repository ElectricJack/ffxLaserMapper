import com.fieldfx.math.*;
import com.fieldfx.serialize.*;
import java.util.List;


import hypermedia.net.*; // import UDP library
import processing.net.*; // import TCP library 
//import peasy.*;

UDP      udp;        // UDP Listener
Client   etherdream;
//PeasyCam cam;

final String  fileName = "mapping.json";
final boolean log      = false;

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

// tag edges
// select [tags]
// execute pattern with params



void setup()
{
	size(800,600,P3D);

	udp   = new UDP( this, 7654 );
	store = new JSONSerializer(this);
	store.registerType(new Mapping());
	store.registerType(new EdgeList());
	store.registerType(new PointIndex());
	store.registerType(new Vector2());

	//udp.log( true ); 		// <-- printout the connection activity
	udp.listen( true );

	loadData();
	frameRate(60);
}

void draw()
{
	background(100);
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



	if      (editMode == 0) updateEditPoints();
	else if (editMode == 1) updateEditEdges();

	keyWasPressed = keyPressed;
}






void keyPressed()
{
	if      (key == '1') editMode = 0;
	else if (key == '2') editMode = 1;


  if (keyCode == LEFT) ++currentEdgeList;
  if (keyCode == RIGHT) --currentEdgeList;
  
  int count = data.edgeLists.size();
  if(count > 0) {
    currentEdgeList = (currentEdgeList + count) % count;
 // println("count: "+count);
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
		println("delete point");

		int hoverIndex = data.points.indexOf(hover);
		for(int i=0; i<data.edgeLists.size(); ++i) {
			EdgeList edgeList = data.edgeLists.get(i);
			for (int j=edgeList.loop.size()-1; j >= 0; --j) {
				PointIndex pi = edgeList.loop.get(j);
				if(pi.index == hoverIndex) {
					edgeList.loop.remove(pi);
				}
			}
		}
		data.points.remove(hover);

		saveData();
	}

	// Click to add points
	else if (mouseUp) {
		println("add point "  + wasMousePressed + ", " + (!mousePressed) + ", " + (!dragging));
		data.points.add(new Vector2(x,y));
		saveData();
	}

	// Drag to move points
	else if (dragging && hover != null) {
		println("moving point");
		hover.set(x, y);
		saveData();
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
		activeEdgeList.loop.add(indexOfPoint(hover));
	}

	if (keyPressed && !keyWasPressed && keyCode == ENTER) {
    if (activeEdgeList.loop.size() > 1) {
  		data.edgeLists.add(activeEdgeList);
  		saveData();
    }
    activeEdgeList = new EdgeList();
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
	float   x = mouseX / (float)width;
	float   y = mouseY / (float)height;
  strokeWeight(1);
	int count = edgeList.loop.size();
	for(int i=0; i<count; ++i) {
		Vector2 from = data.points.get(edgeList.loop.get(i).index);
		Vector2 to   = null;

		if (i+1 < count) {
			to = data.points.get(edgeList.loop.get(i+1).index);
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
		hover = data.findClosestPoint(x,y,30.0/width);
	}

	// Draw the hover
	if (hover != null) {
		fill(0);
		drawPoint(hover, 5);
	}
}

PointIndex  indexOfPoint(Vector2 pt)    { return new PointIndex(data.points.indexOf(pt)); }
void        loadData()                  { try {store.load(sketchPath(fileName), data);} catch(Exception e) {} }
void        saveData()                  { store.save(sketchPath(fileName), data); }

void drawPoints()
{
	fill(255);
	noStroke();
	float s = 2;
	for (int i=0; i<data.points.size(); ++i) {
		Vector2 point = data.points.get(i);
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
