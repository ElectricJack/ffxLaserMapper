import com.fieldfx.math.*;
import com.fieldfx.serialize.*;
import java.util.List;


import hypermedia.net.*; // import UDP library
import processing.net.*; // import TCP library 


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

boolean         laserMouse = false;
boolean         drawLaser = true;

// tag edges
// select [tags]
// execute pattern with params


// Need to be able to trigger different edges with effects from different OSC triggers   enable/disable for each edge/effect
// Need to be able to playback motion of laser over a calibrated laser path. Hard-coded duration for the playback, option to stop/loop
//   - Already prototyped loading the laser path
//   - Need to be able to interpolate the path based on a function of the entire paths length.
//     - On initialization calculate all edge lengths and store at the start of each vertex
//     - To find a location in time t from 0-1, multiply by total path length, then keep subtracting edge lengths until you fall within an edge length
// Need the ability to trigger more than one laser loop path animation at a time
// Need to be able to preview the path with the laser and align it to the geometry


LaserPath path;

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
	path = new LaserPath("accelerator-path.obj");

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


	placeLaserPath();

	if      (editMode == 0) updateEditPoints();
	else if (editMode == 1) updateEditEdges();
	//else if (editMode == 2) placeLaserPath();


	keyWasPressed = keyPressed;
}




void keyPressed()
{
	if      (key == '1') editMode = 0;
	else if (key == '2') editMode = 1;
	//else if (key == '3') editMode = 2;

	if (keyCode == LEFT) ++currentEdgeList;
	if (keyCode == RIGHT) --currentEdgeList;

	int count = data.edgeLists.size();
	if(count > 0) {
		currentEdgeList = (currentEdgeList + count) % count;
		// println("count: "+count);
	}
}

float time;
void placeLaserPath()
{
	path.draw();

	time += 0.001;
	time %= 1.0;
	Vector2 at = path.getPositionAtTime(time);
	if (at != null) {
		fill(255);
		ellipse(at.x, at.y, 5,5);
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
