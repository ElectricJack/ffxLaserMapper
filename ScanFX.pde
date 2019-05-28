
float animTime = 0;

void scanPointOnPath()
{
  if (!laserEnabled)
    return;
    
  Vector2 at = data.path.getPositionAtTime(time);
  if (at != null) {
    fill(255,0,0);
    ellipse(at.x, at.y, 10,10);
    
    at.diveq(width, height);

    setPointRate(1000);
    setColor(0);
    addPoint(at.x, at.y);
    setColor(1);
    addPoint(at.x, at.y);
    addPoint(at.x, at.y);
  }
}

void scanChargeLaser(int index)
{
  float power = laserPowerLevel[index];
  if(power > 0) {
    //println("POWER ON " + index + " " + power);
    EdgeList edgeList  = data.edgeLists.get(1);
    int      vertIndex = edgeList.loop.get(index).index;
    Vector2  at        = data.points.get(vertIndex).get();
    float s = 0.01;
    at.x += random(-s,s);
    at.y += random(-s,s);
    setPointRate(blankingPointRate);
    setColor(0);
    addPoint(at.x, at.y);

    setColor(power);
    for(int i=0; i<4; ++i)
        addPoint(at.x, at.y);
  }
}

void scanLaserEffects()
{
  if(laserEffectMode == 0)
  {
    scanEdgeList(data.edgeLists.get(currentEdgeList));
  }
  else if(laserEffectMode == 0)
  {
    
  }
  else if(laserEffectMode == 0)
  {
    
  }
  else if(laserEffectMode == 0)
  {
    
  }
}


void scanEdgeList(EdgeList edgeList) {

  if (edgeList.loop.size() < 1)
    return;

  int firstIndex = edgeList.loop.get(0).index;
  if(firstIndex >= data.points.size())
    return;

  animTime += 0.02f;

  Vector2 first = data.points.get(firstIndex);
  Vector2 last = null;

  setPointRate(blankingPointRate);
  setColor(0);
  addPoint(first.x,first.y);

  setColor(1);
  
  int scanType = 2;

  int count = edgeList.loop.size();
  for(int i=0; i<count; ++i) {
    int fromIndex = edgeList.loop.get(i).index;

    // Handle null checks from deleting verts in edit mode
    if (fromIndex >= data.points.size())
      continue;

    Vector2 from = data.points.get(fromIndex);

    if(i < count-1) {
      int toIndex = edgeList.loop.get((i+1)).index;
      if (toIndex >= data.points.size())
        continue;

      Vector2 to = data.points.get(toIndex);

      if      (scanType == 0) scanBasic(from, to);
      else if (scanType == 1) scanLightning(from, to);
      else if (scanType == 2) scanDotted(from, to);

      last = to;
      addPoint(last.x, last.y);
    }

  }  
}

void scanBasic(Vector2 from, Vector2 to)
{
  Vector2 diff = to.sub(from);
  int count = max(min((int)floor(diff.len() / 0.05f), 8), 1);
  //println("len: "+diff.len());
  for(int i=0; i<count; ++i)
  {
    float t = i / (float)count;
    Vector2 at = from.add(diff.mul(t));
    addPoint(at.x, at.y);
  }
}

void scanDotted(Vector2 from, Vector2 to)
{
  setPointRate(5000);

  Vector2 diff = to.sub(from);
  int count = max(min((int)floor(diff.len() / 0.05), 16), 1);
  float segLength = 1.0 / count;
  float segOffset = segLength * (animTime % 1.0);
  Vector2 offsetSegment = diff.mul(segOffset);
  for(int i=0; i<=count; ++i)
  {
    float col = floor((animTime+i)%2);
    setColor(col,col,col);

    float t = i / (float)count;
    Vector2 at;
    if (i == 0) {
      at = from.add(offsetSegment);
      addPoint(at.x, at.y);
    } else if (i == count) {
      at = to;//from.add(diff.sub(diff.mul(t)));
      addPoint(at.x, at.y);
    } else {
      at = from.add(diff.mul(t).add(offsetSegment));
      addPoint(at.x, at.y);
    }

  }
}

void scanLightning(Vector2 from, Vector2 to)
{
  setPointRate(4000);

  Vector2 diff = to.sub(from);
  float resolutionLen = 0.02f;
  int count = max(min((int)floor(diff.len() / resolutionLen), 16), 1);

  Vector2 tangent = diff.nrm();
  Vector2 normal  = new Vector2(-tangent.y, tangent.x);

  for(int i=0; i<=count; ++i)
  {
    float t = i / (float)count;

    float env = sin(t*PI);
    float offsetScalar = (noise(i*0.4 + animTime) - 0.5) * 0.1 + (random(1) - 0.5) * 0.02;
    //float offsetScalar = ;
    Vector2 at = from.add(diff.mul(t)).add(normal.mul(offsetScalar * env));
    addPoint(at.x, at.y);
  }
}