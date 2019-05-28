


float nextUpdateTime;
void updateEtherDream()
{
  // Wait until we need more data before update again
  if (millis() < nextUpdateTime)
    return;

  // if (etherdream != null && etherdream.available() > 0) { 
  //   byte[] byteBuffer = new byte[32];
  //   int byteCount = etherdream.readBytes(byteBuffer);
  //   //println("byte count: " + byteCount);
  //   parseDacStatus(byteBuffer, 0);
  // } 

  beginPoints(blankingPointRate);

  setColor(0,0,0);
  addPoint(-0.5,-0.5);
  //for(int i=0; i<10; ++i){
  //  addPoint(-0.5,-0.5);
  //}
  
  if (laserMouse) {
    float mx = (float)mouseX/width;
    float my = (float)mouseY/height;

    addPoint(mx,my);
    setColor(1,1,1);
    addPoint(mx,my);
    setColor(0,0,0);
    addPoint(mx,my);

  }

  if (drawLaserAnimationPath) {
    data.path.scanPath();
  }


  scanPointOnPath();
  
    
  if(currentEdgeList >= 0 && currentEdgeList < data.edgeLists.size())
  {
    //println("current: " + currentEdgeList);
    EdgeList scanEdgeList = data.edgeLists.get(currentEdgeList);
    scanEdgeList(scanEdgeList);
    //clear();
  }



  if (etherdream != null) {
    etherdream.write(commandPrepareStream());

    // Write out all the upcoming point rate changes
    for(int i=1; i<pointRateChangeCount; ++i) {
      etherdream.write(commandQueueRateChange(pointRates[i].pointRate));
    }

    // Write all point date
    etherdream.write(commandWriteData());

    //etherdream.write(commandBeginPlayback(0,5000));
    etherdream.write(commandBeginPlayback(0,pointRates[0].pointRate));
  }
  
  colorMode(RGB,255);
  visualizeLaser();
}




public static int unsignedByte(byte b) {
  return b & 0xFF;
}
  



// ------------------------------------------------------------------------------------ //
// This command causes the playback system to enter the Prepared state. 
// The DAC resets its buffer to be empty and sets "point_count" to 0. This 
// command may only be sent if the light engine is Ready and the playback system
// is Idle. If so, the DAC replies with ACK; otherwise, it replies with NAK - Invalid.
byte[] commandPrepareStream() {
  return new byte[] { 'p' };
}

// ------------------------------------------------------------------------------------ //
// This causes the DAC to begin producing output. point_rate is the number of points 
// per second to be read from the buffer. If the playback system was Prepared and there 
// was data in the buffer, then the DAC will reply with ACK; otherwise, it replies with 
// NAK - Invalid.
//
// TODO: The low_water_mark parameter is currently unused.
byte[] commandBeginPlayback(int lowWaterMark, int pointRate)
{
  byte[] byteBuffer = new byte[7];
  byteBuffer[0] = 'b';
  byteBuffer[1] = (byte)( lowWaterMark       & 0xFF);
  byteBuffer[2] = (byte)((lowWaterMark >> 8) & 0xFF);
  byteBuffer[3] = (byte)( pointRate          & 0xFF);
  byteBuffer[4] = (byte)((pointRate >>  8)   & 0xFF);
  byteBuffer[5] = (byte)((pointRate >> 16)   & 0xFF);
  byteBuffer[6] = (byte)((pointRate >> 24)   & 0xFF);
  return byteBuffer;
}

// ------------------------------------------------------------------------------------ //
// This adds a new point rate to the point rate buffer. Point rate changes are read out 
// of the buffer when a point with an appropriate flag is played; see the Write Data 
// command. If the DAC is not Prepared or Playing, it replies with NAK - Invalid. If 
// the point rate buffer is full, it replies with NAK - Full. Otherwise, it replies 
// with ACK.
byte[] commandQueueRateChange(int pointRate)
{
  byte[] byteBuffer = new byte[5];
  byteBuffer[0] = 'q';
  byteBuffer[1] = (byte)(pointRate         & 0xFF);
  byteBuffer[2] = (byte)((pointRate >>  8) & 0xFF);
  byteBuffer[3] = (byte)((pointRate >> 16) & 0xFF);
  byteBuffer[4] = (byte)((pointRate >> 24) & 0xFF);
  return byteBuffer;
}

// ------------------------------------------------------------------------------------ //
// This provides data for the DAC to add to its buffer. The data values are full-scale 
// (for instance, for color channels, 65535 is full output); the least-significant bits of each 
// word will be ignored if the DAC’s resolution is less than 16 bits.
byte[] commandWriteData() {
  //struct data_command {
  //  uint8_t command; /* ‘d’ (0x64) */
  //  uint16_t npoints;
  //  struct dac_point data[];
  //};

  //println("Sending points: "+pointCount);
  
  byte[] byteBuffer = new byte[3 + 18*pointCount];
  byteBuffer[0] = 'd';
  byteBuffer[1] = (byte)( pointCount       & 0xFF);
  byteBuffer[2] = (byte)((pointCount << 8) & 0xFF);

  if (log)
    println("Sending " + byteBuffer.length + " bytes.");
 
  // The first index (index zero) always stores just the initial point rate
  //  so we start looking for the second index
  int nextRateChangeIndex = 1;

  int pointsPerSecond = pointRates[0].pointRate;
  int pointsAtRate = 0;
  float timeTillNextUpdate = 0;

  for(int i=0; i<pointCount; ++i, ++pointsAtRate) {
    //struct dac_point {
    //  uint16_t control;
    //  int16_t x;
    //  int16_t y;
    //  uint16_t i;
    //  uint16_t r;
    //  uint16_t g;
    //  uint16_t b;
    //  uint16_t u1;
    //  uint16_t u2;
    //};
    int off = 3 + 18*i;
    PointData p = points[i];

    // Check if this point index is a rate change and set the flag and increment if so
    boolean isPointRateChange = false;
    if (nextRateChangeIndex < pointRateChangeCount &&
        pointRates[nextRateChangeIndex].indexOfStart == i) {

      isPointRateChange = true;
      
      timeTillNextUpdate += (float)pointsAtRate / pointsPerSecond;
      pointsPerSecond = pointRates[nextRateChangeIndex].pointRate;
      pointsAtRate = 0;

      ++nextRateChangeIndex;
    }
    
    byteBuffer[off+0] = 0;
    byteBuffer[off+1] = isPointRateChange ? (byte)(1 << 7) : 0; // 15th bit to enable rate change
    
    byteBuffer[off+2] = (byte)( p.x       & 0xFF); // Low
    byteBuffer[off+3] = (byte)((p.x >> 8) & 0xFF); // High
    
    byteBuffer[off+4] = (byte)( p.y       & 0xFF);
    byteBuffer[off+5] = (byte)((p.y >> 8) & 0xFF);
    
    
    byteBuffer[off+6] = (byte)(p.r        & 0xFF);
    byteBuffer[off+7] = (byte)((p.r >> 8) & 0xFF);
    
    byteBuffer[off+8] = (byte)(p.g        & 0xFF);
    byteBuffer[off+9] = (byte)((p.g >> 8) & 0xFF);

    byteBuffer[off+10] = (byte)(p.b        & 0xFF);
    byteBuffer[off+11] = (byte)((p.b >> 8) & 0xFF);

    byteBuffer[off+14] = 0;
    byteBuffer[off+15] = 0;
    
    byteBuffer[off+16] = 0;
    byteBuffer[off+17] = 0;
  }

  timeTillNextUpdate += (float)pointsAtRate / pointsPerSecond;
  pointsAtRate = 0;
  nextUpdateTime = millis() + timeTillNextUpdate*1000.0f + 10; //10ms buffer to avoid flooding
  
  return byteBuffer;
}




class PointData {
  int x,y;
  int i;
  int r;
  int g;
  int b;
  int u1;
  int u2;
}

class PointDataRateChange
{
  int indexOfStart;
  int pointRate;
}

final int kMaxPointData           = 10000;
final int kMaxPointRateChangeData = 100;
final int kDefaultPointRate       = 1000;

int                   pointRateChangeCount=0;
PointDataRateChange[] pointRates;
int                   pointCount=0;
PointData[]           points;
float                 _r, _g, _b;


// For visualization
void visualizeLaser() {
  if(!drawLaser) return;
  
  strokeWeight(3);
  for(int i=0; i<pointCount-1; ++i) {
    stroke(points[i].r / 256, points[i].g / 256, points[i].b / 256);
    float x0 = width  * ((points[i].x / 65535.0 + 0.5f) % 1); 
    float y0 = height * ((points[i].y / 65535.0 + 0.5f) % 1);
    float x1 = width  * ((points[i + 1].x / 65535.0 + 0.5f) % 1); 
    float y1 = height * ((points[i + 1].y / 65535.0 + 0.5f) % 1);
    line(x0,y0,x1,y1);
    rect(x0-2,y0-2,4,4);
  }
}

void clear()
{
  PointData last = points[points.length-1];
  setColor(0,0,0);
  for(int i=0; i<4; ++i)
    addPoint(last.x, last.y);
}

void beginPoints() { 
  beginPoints(kDefaultPointRate);
}
void beginPoints(int pointRate) {
  if (points == null) {
    points = new PointData[kMaxPointData];
    for (int i=0; i<points.length; ++i)
      points[i] = new PointData();
  }

  if (pointRates == null) {
    pointRates = new PointDataRateChange[200];
    for (int i=0; i<pointRates.length; ++i)
      pointRates[i] = new PointDataRateChange();
  }

  pointCount=0;
  activePointRate = pointRate;
  pointRateChangeCount=0;
  pointRates[pointRateChangeCount++].pointRate = pointRate;

  setColor(0,0,0);
}
int activePointRate = 1000;
void setPointRate(int pointRate) {
  activePointRate = pointRate;
}

void setColor(float r, float g, float b) {
  _r=r; _g=g; _b=b;
}

void addPoint(float x, float y) {
  if (pointCount >= points.length)
  	return;

  if( pointRateChangeCount < kMaxPointRateChangeData &&
      activePointRate != pointRates[pointRateChangeCount-1].pointRate )
  {
    //println("changing point rate ("+pointRateChangeCount+"): " + activePointRate);
    pointRates[pointRateChangeCount].pointRate    = activePointRate;
    pointRates[pointRateChangeCount].indexOfStart = pointCount;
    ++pointRateChangeCount;
  }

  PointData p = points[pointCount++];
  
  // Wierd translation mapping
  // 0   - 0.5 ==> 0.5 - 1
  // 0.5 - 1   ==> 0 - 0.5
  p.x  = (int)(((x + 0.5f) % 1.0f) * 65535);
  p.y  = (int)(((y + 0.5f) % 1.0f) * 65535);
  p.i  = 0;
  p.r  = (int)(constrain(_r,0.0f,1.0f) * 65535);
  p.g  = (int)(constrain(_g,0.0f,1.0f) * 65535);
  p.b  = (int)(constrain(_b,0.0f,1.0f) * 65535);
  p.u1 = 0;
  p.u2 = 0;
}


void receive( byte[] data, String ip, int port )
{
  if (etherdream == null) {
    println("Connecting to " + ip + " on port 7765");
    etherdream = new Client(this, ip, 7765);
  }
  
  if (log)
    println("Recieved " + data.length + " bytes of UDP data from: "+ip+" on port: "+port);

  if (data.length == 22)
    parseResponse(data, 0);
  else if (data.length == 36)
    parseBroadcast(data, 0);
}

void parseResponse(byte[] byteBuffer, int i) // 2 bytes + 20 byte status
{
  int response = unsignedByte(byteBuffer[i+0]);
  int command  = unsignedByte(byteBuffer[i+1]);

  if      (response == 0x61) println("Response ("+command+"): ACK");
  else if (response == 0x46) println("Response ("+command+"): Error - Buffer full!");
  else if (response == 0x49) println("Response ("+command+"): Error - Invalid!");
  else if (response == 0x21) println("Response ("+command+"): EStop condition!!");
  
  parseDacStatus(byteBuffer, i+2);
}
// ------------------------------------------------------------------------------------ //
void parseBroadcast(byte[] byteBuffer, int i) // 16 bytes + 20 byte status
{
  //struct j4cDAC_broadcast {
  //  uint8_t mac_address[6];s
  //  uint16_t hw_revision;
  //  uint16_t sw_revision;
  //  uint16_t buffer_capacity;
  //  uint32_t max_point_rate;
  //        struct dac_status status;
  //};
  
  String macAddress = unsignedByte(byteBuffer[i+0]) + "." +
                      unsignedByte(byteBuffer[i+1]) + "." +
                      unsignedByte(byteBuffer[i+2]) + "." +
                      unsignedByte(byteBuffer[i+3]) + "." +
                      unsignedByte(byteBuffer[i+4]) + "." +
                      unsignedByte(byteBuffer[i+5]);
  
  int hwRevision     = (byteBuffer[i+6] & 0xFF) | (byteBuffer[i+7] & 0xFF) <<  8;
  int swRevision     = (byteBuffer[i+8] & 0xFF) | (byteBuffer[i+9] & 0xFF) <<  8;
  int bufferCapacity = (byteBuffer[i+10] & 0xFF) | (byteBuffer[i+11] & 0xFF) <<  8;
  int maxPointRate   = (byteBuffer[i+12] & 0xFF) | (byteBuffer[i+13] & 0xFF) <<  8 | (byteBuffer[i+14] & 0xFF) << 16 | (byteBuffer[i+15] & 0xFF) << 24;
  
  if (log) {
    println("macAddress:     "+macAddress);
    println("hwRevision:     "+hwRevision);
    println("swRevision:     "+swRevision);
    println("bufferCapacity: "+bufferCapacity);
    println("maxPointRate:   "+maxPointRate);
  }
  
  parseDacStatus(byteBuffer, i+16);
}

// ------------------------------------------------------------------------------------ //
void parseDacStatus(byte[] byteBuffer, int i) // 20 bytes
{
  //struct dac_status {
  //        uint8_t protocol;
  //        uint8_t light_engine_state;
  //        uint8_t playback_state;
  //        uint8_t source;
  //        uint16_t light_engine_flags;
  //        uint16_t playback_flags;
  //        uint16_t source_flags;
  //        uint16_t buffer_fullness;
  //  uint32_t point_rate;
  //  uint32_t point_count;
  //};
    
  int protocol         = unsignedByte(byteBuffer[i+0]);
  int lightEngineState = unsignedByte(byteBuffer[i+1]);
  int playbackState    = unsignedByte(byteBuffer[i+2]);
  int source           = unsignedByte(byteBuffer[i+3]);
  
  int lightEngineFlags = (byteBuffer[i+4] & 0xFF) | (byteBuffer[i+5] & 0xFF) <<  8 ;  
  int playbackFlags    = (byteBuffer[i+6] & 0xFF) | (byteBuffer[i+7] & 0xFF) <<  8 ;
  int sourceFlags      = (byteBuffer[i+8] & 0xFF) | (byteBuffer[i+9] & 0xFF) <<  8 ;
  int bufferFullness   = (byteBuffer[i+10] & 0xFF) | (byteBuffer[i+11] & 0xFF) <<  8 ;
  int pointRate        = (byteBuffer[i+12] & 0xFF) | (byteBuffer[i+13] & 0xFF) << 8 | (byteBuffer[i+14] & 0xFF) << 16 | (byteBuffer[i+15] & 0xFF) << 24;
  int pointCount       = (byteBuffer[i+16] & 0xFF) | (byteBuffer[i+17] & 0xFF) << 8 | (byteBuffer[i+18] & 0xFF) << 16 | (byteBuffer[i+19] & 0xFF) << 24;
  
  if(log) {
    println("protocol:         " + (int)protocol);
    println("lightEngineState: " + (int)lightEngineState);
    println("playbackState:    " + (int)playbackState);
    println("source:           " + (int)source);
    
    println("lightEngineFlags: " + lightEngineFlags);
    println("playbackFlags:    " + playbackFlags);
    println("sourceFlags:      " + sourceFlags);
    
    println("bufferFullness: " + bufferFullness);
    println("pointRate:      " + pointRate);
    println("pointCount:     " + pointCount);
  }
}
