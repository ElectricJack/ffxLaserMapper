
class LaserPath implements Serializable
{

  ArrayList<LaserVert> verts = new ArrayList<LaserVert>();

  public String  sourcePath = "accelerator-path.obj";

  public Vector2 lastCenter = new Vector2();
  public Vector2 center     = new Vector2();
  public Vector2 top        = new Vector2();
  public Vector2 right      = new Vector2();

  public Vector2 size       = new Vector2(400, 400);
  public float   rotation;


  public LaserPath clone()   { return new LaserPath(); }
  public String    getType() { return "LaserPath"; }
  public void serialize(Serializer s)
  {
    sourcePath = s.serialize("sourcePath", sourcePath);
    if (s.isLoading())
    {
      load(sourcePath);
    }

    s.serialize("center",  center);
    s.serialize("size",    size);

    rotation = s.serialize("rotation", rotation);
  }

  
  private class LaserVert
  {
    Vector3 pos;
    Vector2 uv;
    float   t;
    float   distToNext;
    
    LaserVert(PVector pos, float u, float v) {
      this.pos = new Vector3(pos.x, pos.y, pos.z);
      this.uv  = new Vector2(u,v);
    }
  }
  
  
  boolean isLoaded() { return verts.size() > 0; }

  void load(String path)
  {
    laserPath = loadShape(path);
    PShape[] children  = laserPath.getChildren();
    laserPath = children[0];
  
    println("verts: " + laserPath.getVertexCount());
    int totalVerts = laserPath.getVertexCount();
    for(int i=0; i<totalVerts; ++i) {
      float u = laserPath.getTextureU(i);
      float v = laserPath.getTextureV(i);
      verts.add(new LaserVert(laserPath.getVertex(i), u, v));
    }
    
    // Calculate the worldspace distances to the next vertex
    float totalLength = 0;
    for(int i=0; i<totalVerts; ++i) {
      LaserVert cur  = verts.get(i);
      LaserVert next = verts.get((i+1)%totalVerts);
      cur.distToNext = next.pos.sub(cur.pos).len();
      totalLength += cur.distToNext;
    }
    
    float currentDist = 0;
    for(int i=0; i<totalVerts; ++i) {
      LaserVert cur = verts.get(i);
      cur.t = currentDist / totalLength;
      currentDist += cur.distToNext;
    }

    // Init handles
    center.x = 0.5;
    center.y = 0.5;
    top.set(   center.sub(0.0f, 0.5*size.y / height));
    right.set( center.add(0.5*size.x / width, 0.0f));

    addPoint(center, false);
    addPoint(top,    false);
    addPoint(right,  false);
  }
  
  void draw()
  {
    updateTransform();

    stroke(255);
    strokeWeight(1);
    noFill();

    pushMatrix();
      applyTransform();
      rect(0,0,size.x,size.y);

      int vertCount = verts.size();
      for (int i=0; i<vertCount; ++i) {
        int i2 = (i+1) % vertCount;

        LaserVert cur  = verts.get(i);
        LaserVert next = verts.get(i2);

        float x0 = cur.uv.x  * size.x;
        float y0 = cur.uv.y  * size.y;
        float x1 = next.uv.x * size.x;
        float y1 = next.uv.y * size.y;

        line(x0, y0, x1, y1);
      }
    popMatrix();
  }

  void scanPath()
  {
    
    pushMatrix();
      applyTransform();

      setColor(0,0,0);
      setPointRate(blankingPointRate);

      Vector2 first = laserCoordPoint(0);
      addPoint(first.x, first.y);

      setColor(1,1,1);
      setPointRate(5000);

      int totalVerts = verts.size();
      for (int i=1; i<totalVerts; ++i) {
        Vector2 at = laserCoordPoint(i%totalVerts);
        addPoint(at.x, at.y);
      }

      setPointRate(blankingPointRate);
      addPoint(first.x, first.y);
      setColor(0,0,0);
      addPoint(first.x, first.y);

    popMatrix();
  }

  private Vector2 laserCoordPoint(int index)
  {
    LaserVert cur = verts.get(index);
    return new Vector2(
      screenX(cur.uv.x*size.x, cur.uv.y*size.y, 0) / width,
      screenY(cur.uv.x*size.x, cur.uv.y*size.y, 0) / height
    );
  }
  
  Vector2 getPositionAtTime(float t)
  {
    // Wrap 0-1
    t = t % 1.0f;//min(max(t,0),1);
    
    // Should do a binary search for performance but we are going to start with the trivial impl
    Vector2 uvResult = null;

    int totalVerts = verts.size();
    for(int i=0; i<totalVerts-1; ++i)
    {
      LaserVert v0 = verts.get(i);
      LaserVert v1 = verts.get(i+1);
      if (t >= v0.t && t < v1.t) {
        float innerT = (t - v0.t) / (v1.t - v0.t);
        uvResult = (new Vector2()).lerp(v0.uv, v1.uv, innerT);
        break;
      }
    }

    // Handle wrapping back to start
    LaserVert last = verts.get(totalVerts-1);
    if(t >= last.t) {
        float innerT = (t - last.t) / (1.0 - last.t);
        LaserVert first = verts.get(0);
        uvResult = (new Vector2()).lerp(last.uv, first.uv, innerT);
    }
    
    if(uvResult != null) {
      pushMatrix();
        applyTransform();
        uvResult.set(
          screenX(uvResult.x*size.x, uvResult.y*size.y, 0),
          screenY(uvResult.x*size.x, uvResult.y*size.y, 0)
        );
      popMatrix();
    }
    
    return uvResult;
  }

  void updateTransform()
  {
    if (center.sub(lastCenter).len() < 0.0001f) {
      size.x = right.sub(center).len() * width * 2.0;
      size.y = top.sub(center).len() * height * 2.0;

      rotation = right.sub(center).ang();
    }

    Vector2 topOff = new Vector2(0.0f, 0.5*size.y / height);
    top.set(center.sub(topOff.rot(rotation)));
    Vector2 rightOff = new Vector2(0.5*size.x / width, 0.0f);
    right.set(center.add(rightOff.rot(rotation)));

    lastCenter.set(center);
  }

  void applyTransform()
  {
    translate(center.x*width, center.y*height, 0);
    rotateZ(rotation);
    translate(-size.x/2, -size.y/2, 0);
  }
  
  PShape laserPath;
}