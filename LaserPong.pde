

class LaserPong implements Serializable
{
  public Vector2 lastCenter;
  public Vector2 center;
  public Vector2 top;
  public Vector2 right;

  public Vector2 size       = new Vector2(400, 400);
  public float   rotation;

  public LaserPong clone()   { return new LaserPong(); }
  public String    getType() { return "LaserPong"; }


  Vector2 ballPos    = new Vector2();
  Vector2 ballVel     = new Vector2();
  float[] paddlePos  = new float[2];
  float[] paddleSize = new float[2];

  public void serialize(Serializer s)
  {
    s.serialize("center",  center);
    s.serialize("size",    size);

    rotation = s.serialize("rotation", rotation);

    if(s.isLoading())
    {
    		init();
    }
  }

  boolean isInitialized() { return center != null; }

  void init()
  {
  	lastCenter = new Vector2();
  	center     = new Vector2();
  	top        = new Vector2();
  	right      = new Vector2();


		// Init handles
		center.x = 0.5;
		center.y = 0.5;
		top.set(   center.sub(0.0f, 0.5*size.y / height));
		right.set( center.add(0.5*size.x / width, 0.0f));


    paddlePos[0] = 0.5;
    paddlePos[1] = 0.5;
    paddleSize[0] = size.y / 4;
    paddleSize[1] = size.y / 4;


		addPoint(center, false);
		addPoint(top,    false);
		addPoint(right,  false);

		respawn();
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

      ballPos.inc(ballVel);
      if (ballPos.x < 0)      { ballPos.x = 0;      ballVel.x *= -1; }
      if (ballPos.x > size.x) { ballPos.x = size.x; ballVel.x *= -1; }
      if (ballPos.y < 0)      { ballPos.y = 0;      ballVel.y *= -1; }
      if (ballPos.y > size.y) { ballPos.y = size.y; ballVel.y *= -1; }

      ellipse(ballPos.x, ballPos.y, 10,10);

    popMatrix();
  }
  void scan()
  {
    pushMatrix();
      applyTransform();

      Vector2 tl = new Vector2(0,0);
      Vector2 tr = new Vector2(size.x,0);
      Vector2 bl = new Vector2(0,size.y);
      Vector2 br = new Vector2(size.x,size.y);

      drawLineSegment(tl,tr);
      drawLineSegment(br,bl);

      Vector2 paddleLeft  = new Vector2(0,     (size.y-paddleSize[0]) * paddlePos[0]);
      Vector2 paddleRight = new Vector2(size.x,(size.y-paddleSize[1]) * paddlePos[1]);
      drawLineSegment(paddleLeft,paddleLeft.add(0,paddleSize[0]));
      drawLineSegment(paddleRight,paddleRight.add(0,paddleSize[1]));

      setColor(0,0,0);
      setPointRate(blankingPointRate);

      Vector2 laserAt = laserCoordPoint(ballPos);
      addPoint(laserAt.x, laserAt.y);

      setColor(1);
      setPointRate(2500);
      addPoint(laserAt.x, laserAt.y);
      addPoint(laserAt.x, laserAt.y);

    popMatrix();
  }

  void drawLineSegment(Vector2 from, Vector2 to)
  {
      Vector2 laserAt = laserCoordPoint(from);
      setColor(0); setPointRate(blankingPointRate);
      addPoint(laserAt.x, laserAt.y);

      setColor(1); setPointRate(2500);
      addPoint(laserAt.x, laserAt.y);
      addPoint(laserAt.x, laserAt.y);

      laserAt = laserCoordPoint(to);
      addPoint(laserAt.x, laserAt.y);
      addPoint(laserAt.x, laserAt.y);
  }

  void respawn()
  {
		ballPos.set(size).muleq(0.5);
		ballVel.set(random(-5,5), random(-5,5));
  }
  private Vector2 laserCoordPoint(Vector2 pongCoord)
  {
    return new Vector2(
      screenX(pongCoord.x, pongCoord.y, 0) / width,
      screenY(pongCoord.x, pongCoord.y, 0) / height
    );
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
}