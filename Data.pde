class PointIndex implements Serializable
{
	public int index;
	public PointIndex() {}
	public PointIndex(int index) {this.index = index;}

	public PointIndex clone()   { return new PointIndex(); }
	public String     getType() { return "PointIndex"; }
	public void serialize(Serializer s)
	{
		index = s.serialize("index", index);
	}
}
class EdgeList implements Serializable
{
	public List<PointIndex> loop = new ArrayList<PointIndex>();
  public String           tags;

	public EdgeList clone()   { return new EdgeList(); }
	public String   getType() { return "EdgeList"; }
	public void serialize(Serializer s)
	{
    tags = s.serialize("tags", tags);
		s.serialize("loop", loop);
	}
}
class Mapping implements Serializable
{
	// Points are stored in 0-1 space for the laser
	public List<Vector2>  points    = new ArrayList<Vector2>();
	public List<EdgeList> edgeLists = new ArrayList<EdgeList>();
	public LaserPath      path      = new LaserPath();


	public Mapping clone()   { return new Mapping(); }
	public String  getType() { return "Mapping"; }
	
	public void serialize(Serializer s)
	{
		s.serialize("points",    points);
		s.serialize("edgeLists", edgeLists);
		s.serialize("path",      path);

		if(s.isLoading())
		{
			movablePoints.addAll(points);
		}
	}
}


void addPoint(Vector2 point, boolean serialize) {
	//println("add point "  + wasMousePressed + ", " + (!mousePressed) + ", " + (!dragging));
	movablePoints.add(point);
	if (serialize)
	{
		data.points.add(point);
		saveData();
	}
}

void removePoint(Vector2 point)
{
	if (!data.points.contains(point))
		return;

	//println("delete point");
	int hoverIndex = data.points.indexOf(point);
	for(int i=0; i<data.edgeLists.size(); ++i) {
		EdgeList edgeList = data.edgeLists.get(i);
		for (int j=edgeList.loop.size()-1; j >= 0; --j) {
			PointIndex pi = edgeList.loop.get(j);
			if(pi.index == hoverIndex) {
				edgeList.loop.remove(pi);
			}
		}
	}

	movablePoints.remove(point);
	data.points.remove(point);

	saveData();
}

List<Vector2> movablePoints = new ArrayList<Vector2>();


Vector2 findClosestPoint(float x, float y, float limit) {
	Vector2 closest     = null;
	Vector2 to          = new Vector2(x,y);
	float   closestDist = Float.MAX_VALUE;

	for (int i=0; i<movablePoints.size(); ++i) {
		Vector2 point = movablePoints.get(i);
		float dist = point.sub(to).len();
		if (dist <= limit && dist < closestDist) {
			closestDist = dist;
			closest     = point;
		}
	}

	return closest;
}

PointIndex  indexOfPoint(Vector2 pt) {
	int index = data.points.indexOf(pt);
	if (index == -1) return null;
	return new PointIndex(index);
}

void        loadData()                  { try {store.load(sketchPath(fileName), data);} catch(Exception e) {} }
void        saveData()                  { store.save(sketchPath(fileName), data); }