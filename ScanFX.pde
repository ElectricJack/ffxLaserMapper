void scanEdgeList(EdgeList edgeList) {
  
  if (edgeList.loop.size() < 1)
    return;
  
  int firstIndex = edgeList.loop.get(0).index;
  if(firstIndex >= data.points.size())
    return;

  Vector2 first = data.points.get(firstIndex);
  Vector2 last = null;
  
  setPointRate(blankingPointRate);
  setColor(0,0,0);
  addPoint(first.x,first.y);
  setColor(1,1,1);
  
  int scanType = 1;
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

      last = to;
      addPoint(last.x, last.y);
    }


  }  
  
  // if(last != null)
  // {
  //  setColor(0,0,0);
  //  addPoint(last.x, last.y);
  // }
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

float animTime = 0;

void scanLightning(Vector2 from, Vector2 to)
{
  setPointRate(4000);

  animTime += 0.06f;
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
