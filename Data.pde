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


	public Mapping clone()   { return new Mapping(); }
	public String  getType() { return "Mapping"; }
	public void serialize(Serializer s)
	{
		s.serialize("points",    points);
		s.serialize("edgeLists", edgeLists);
	}


	Vector2 findClosestPoint(float x, float y, float limit) {
		Vector2 closest     = null;
		Vector2 to          = new Vector2(x,y);
		float   closestDist = Float.MAX_VALUE;

		for (int i=0; i<points.size(); ++i) {
			Vector2 point = points.get(i);
			float dist = point.sub(to).len();
			if (dist <= limit && dist < closestDist) {
				closestDist = dist;
				closest = point;
			}
		}

		return closest;
	}
}
