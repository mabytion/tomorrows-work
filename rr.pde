import processing.serial.*;

class Cloud
{
  float x, y;
  float z;

  Cloud()
  {
    this.x = random(xMin, xMax);
    this.y = random(yMin, yMax);
    this.z = cloudHeight + random(-10, 10);
  }

  void cloudy(float h)
  {
    z = h;
    pushMatrix();
    fill(50, 80);
    translate(x, y, z);
    box(random(160, 120), random(60, 80), random(10, 60));
    popMatrix();
  }
}
class Raindrop
{
  float speed = 6;
  float tale = random(40, 120);
  float rainSize = random(1, 4);
  float gravity = rainSize/10;
  float x, y;
  float z;
  boolean dropFlags = true;

  Raindrop(float x, float y, float z)
  {
    this.x = x;
    this.y = y;
    this.z = z;
  }

  void drop()
  {
    if (z<waterLevel)
    {
      dropFlags = false;
      waterLevel += (rainSize/100) * (tale/75);
    }

    if (dropFlags)
    {
      pushMatrix();
      fill(r, g, b, 128);
      translate(x, y, z);
      z -= speed;
      speed += gravity;
      box(rainSize, rainSize, tale);
      popMatrix();
    }
  }

  boolean getDropFlags()
  {
    return dropFlags;
  }
}


class DropReduce extends Thread
{
  void run()
  {
    while (!isInterrupted())
    {
      try
      {
        if (targetRaindrop > raindropMax)
        {
          raindropMax += (targetRaindrop-raindropMax)/10;

          if (targetRaindrop <= raindropMax)
          {
            raindropMax = targetRaindrop;
          }
        }
        if (targetRaindrop <= raindropMax)
        {
          raindropMax -= (raindropMax-targetRaindrop)/10;

          if (targetRaindrop >= raindropMax)
          {
            raindropMax = targetRaindrop;
          }
        }
        sleep(200);
      }
      catch(InterruptedException e)
      {
        e.printStackTrace();
      }
    }
  }
}

class Sink extends Thread
{
  void run()
  {
    while (!isInterrupted())
    {
      try
      {
        waterLevel -= sinkRate;
        if (waterLevel < waterBottom)
        {
          waterLevel = waterBottom;
        }
        if (waterLevel > cloudHeight-50)
        {
          waterLevel = cloudHeight-50;
        }
        sleep(10);
      }
      catch(InterruptedException e)
      {
        e.printStackTrace();
      }
    }
  }
}

class Values extends Thread
{
  private Serial p;
  private byte[] buffer = new byte[8];
  private float humid = 0;
  private int photo = 0;
  private float temp = 0;
  private int data = 0;
  private boolean ready = false;

  public Values(Serial p)
  {
    this.p = p;
  }

  void run()
  {
    while (!isInterrupted())
    {
      if (p.available() > 0)
      {
        try
        {
          delay(1000);
          
          data = p.read();
          if((byte)data != 126)
          {
            continue;
          }
          else
          {
            buffer[0] = (byte)data;
            for (int i=1; i<8; i++)
            {
              data = p.read();
              buffer[i] = (byte)data;
            }
          }

          if ((buffer[0] != 126) || (buffer[7] != 127))
          {
            continue;
          }

          if (!checksum(buffer))
          {
            continue;
          }

          ready = true;
          temp = (buffer[1]) + (buffer[2] / 100.0f);
          humid = buffer[3] + (buffer[4] / 100.0f);
          photo = 0;
          photo = (buffer[5] * 256) + ((int)buffer[6]&(0x000000FF));
        }
        catch(ArrayIndexOutOfBoundsException e)
        {
          print("d ");
        }
      }
    }
  }

  private boolean checksum(byte[] byteArray)
  {
    byte temp = 0;

    for (byte val : byteArray)
    {
      temp += val;
    }

    if ((temp + (~temp+1)) == 0x00)
    {
      return true;
    }

    return false;
  }

  public float getHumidity()
  {
    return humid;
  }

  public int getIlluminance()
  {
    return photo;
  }

  public float getTemp()
  {
    return temp;
  }

  public boolean getReady()
  {
    return ready;
  }

  public String getData()
  {
    String data = new String();

    for (byte b : buffer)
    {
      data += b;
      data += " ";
    }
    return data;
  }
}

int cols, rows;
int scl = 20;
int w=1600;
int h=1200;
float[][] terrain;
float flying=1;

float rotX=PI/3;
float rotZ, scaleFactor;

ArrayList<Raindrop> rd;
ArrayList<Cloud> cd;
int widths = 1600, heights = 1200;
int xMax, yMax;
int xMin, yMin;
int raindropMax = 500;
int targetRaindrop = 500;
int scale = 1;
int margin = 50;
int cloudCount = 1000;
int r = 0, g = 255, b = 255;
float waterLevel;
float waterBottom = -140;
float sinkRate = 0.11;
float cloudHeight = 700;

float humid = 0;
int photo = 0;
float temp = 0;
float aheight=0;

boolean cloudFlags = true;
Values vs = null;

void setup()
{
  size(1200, 900, P3D);
  cols=w/scl;
  rows=h/scl;
  terrain = new float[cols][rows];
  textSize(margin);
  lights();

  xMax = widths/2 - 1;
  xMin = -(widths/2);
  yMax = heights/2 - 1;
  yMin = -(heights/2);
  waterLevel = waterBottom;
  cd = new ArrayList<Cloud>();
  rd = new ArrayList<Raindrop>();
  for (int i=0; i<raindropMax; i++)
  {
    rd.add(new Raindrop(random(xMin, xMax-1)*scale, random(yMin, yMax-1)*scale, cloudHeight));
  }

  for (int i=0; i<cloudCount; i++)
  {
    cd.add(new Cloud());
  }
  Sink sink = new Sink();
  DropReduce reduce = new DropReduce();
  timer = new Timer();

  sink.start();
  reduce.start();

  vs = new Values(new Serial(this, "COM5", 9600));
  vs.start();
}

void draw()
{ 
  background(120, 85, 0);

  translate(575, 400);
  rotateX(rotX);
  rotateZ(rotZ);
  scale(0.35 + scaleFactor);

  if (cloudFlags)
  {
    for (int i=0; i<cloudCount; i++)
    {
      cd.get(i).cloudy(cloudHeight);
    }
  }

  try
  {
    for (int i=0; i<raindropMax; i++)
    {
      if (!rd.get(i).getDropFlags())
      {
        rd.remove(i);
        rd.add(new Raindrop(random(xMin, xMax-1)*scale, random(yMin, yMax-1)*scale, cloudHeight));
      } else
      {
        rd.get(i).drop();
      }
    }
  }
  catch(IndexOutOfBoundsException e)
  {
    for (int i=rd.size(); i<raindropMax; i++)
    {
      rd.add(new Raindrop(random(xMin, xMax-1)*scale, random(yMin, yMax-1)*scale, cloudHeight));
    }
  }  

  pushMatrix();
  beginShape(QUADS);
  // 1
  //fill(0, 255, 255, 50);
  fill(r, g, b, 128);
  vertex(xMin-1, yMin-1, waterBottom);
  vertex(xMin-1, yMax-20+1, waterBottom);
  vertex(xMin-1, yMax-20+1, waterLevel);
  vertex(xMin-1, yMin-1, waterLevel);

  // 2
  vertex(xMin-1, yMin-1, waterBottom);
  vertex(xMax-20, yMin-1, waterBottom);
  vertex(xMax-20, yMax-20+1, waterBottom);
  vertex(xMin-1, yMax-20+1, waterBottom);

  // 3
  vertex(xMin-1, yMax-20+1, waterBottom);
  vertex(xMax-20, yMax-20+1, waterBottom);
  vertex(xMax-20, yMax-20+1, waterLevel);
  vertex(xMin-1, yMax-20+1, waterLevel);

  // 4
  vertex(xMin-1, yMin-1, waterBottom);
  vertex(xMax-20, yMin-1, waterBottom);
  vertex(xMax-20, yMin-1, waterLevel);
  vertex(xMin-1, yMin-1, waterLevel);

  // 5
  vertex(xMax-20, yMin-1, waterBottom);
  vertex(xMax-20, yMax-20+1, waterBottom);
  vertex(xMax-20, yMax-20+1, waterLevel);
  vertex(xMax-20, yMin-1, waterLevel);

  // 6
  vertex(xMin-1, yMin-1, waterLevel);
  vertex(xMax-20, yMin-1, waterLevel);
  vertex(xMax-20, yMax-20+1, waterLevel);
  vertex(xMin-1, yMax-20+1, waterLevel);
  endShape();
  popMatrix();

  fill(0, 255, 255);
  text("cloudheight >> " + cloudHeight + "pixels", xMin, margin*15);
  text("raindrop >> " + raindropMax + "drops", xMin, margin*16);
  text("targetdrop >> " + targetRaindrop + "drops", xMin, margin*17);
  text("waterlevel >> " + (waterLevel+(-waterBottom)) + "pixels", xMin, margin*18);
  text("sink >> " + sinkRate * 100 + "pixels/sec", xMin, margin*19);
  text("key >> " + key, xMin, margin*20);
  text("keyCode >> " + keyCode, xMin, margin*21);
  text("data >> " + vs.getData(), xMin, margin*25);
  if (!vs.getReady())
  {
    text("temp >> " + "Ready", xMin, margin*22);
    text("humid >> " + "Ready", xMin, margin*23);
    text("illumi >> " + "Ready", xMin, margin*24);
  } else
  {
    text("temp >> " + vs.getTemp() + "℃", xMin, margin*22);
    text("humid >> " + vs.getHumidity() + "%", xMin, margin*23);
    text("illumi >> " + vs.getIlluminance(), xMin, margin*24);
  }

  float yoff=flying;
  for (int y=0; y<rows; y++)
  {
    float xoff=0;
    for (int x=0; x<cols; x++)
    {
      terrain[x][y]=map(noise(xoff, yoff), 0, 1, -200, 200);
      xoff +=0.2;
    }
    yoff +=0.2;
  }

  noStroke();

  if (vs.getReady())
  {
    aheight+=0.1;
    if((cloudHeight+500)*sin(radians(aheight))>=cloudHeight){
    pushMatrix();
    fill(255, 255, 0);
    translate(2000*(cos(radians(aheight))), -200, (cloudHeight+500)*sin(radians(aheight)));
    sphere(vs.getTemp()*5);
    pointLight(vs.getIlluminance()/2, vs.getIlluminance()/2, vs.getIlluminance()/2, 2000*cos(radians(aheight)), -200, (cloudHeight+500)*sin(radians(aheight)));
    popMatrix();
    }
    else
    {
      pointLight(0, 0, 0, 2000*cos(radians(aheight)), -200, (cloudHeight+500)*sin(radians(aheight)));
    }
  }


  sinkRate = (vs.getTemp()/200);
  cloudCount = 1000-vs.getIlluminance();
  if(targetRaindrop>=cloudCount&&vs.getHumidity()<=50)
  {
    targetRaindrop = (int)cloudCount;
  }
  else
  {
  targetRaindrop = (int)(1000*(vs.getHumidity()/100));
  }
  

  for (int y=0; y<rows-1; y++)
  {
    beginShape(TRIANGLE_STRIP);
    for (int x=0; x<cols; x++) 
    {
      fill(0, 128-terrain[x][y], 0);
      vertex(x*scl-800, y*scl-600, terrain[x][y]); 
      vertex(x*scl-800, (y+1)*scl-600, terrain[x][y+1]);
    }

    endShape();
  }

  beginShape(TRIANGLE_STRIP);
  for (int x=0; x<cols; x++)
  {
    fill(0, 128-terrain[x][0], 0);
    vertex(x*scl-800, -600, waterBottom);
    vertex(x*scl-800, -600, terrain[x][0]);
  }
  endShape();

  beginShape(TRIANGLE_STRIP);
  for (int x=0; x<cols; x++)
  {
    fill(0, 128-terrain[x][0], 0);
    vertex(x*scl-800, 570, waterBottom);
    vertex(x*scl-800, 570, terrain[x][rows-1]);
  }
  endShape();
}

void mouseDragged()
{ 
  rotZ -= (mouseX - pmouseX) * 0.01;
  rotX -= (mouseY - pmouseY) * 0.01;
}

void mouseWheel(MouseEvent event)
{
  float e = event.getCount();
  scaleFactor += e/10;
}

void keyPressed()
{
  if (key == 'w')
  {
    targetRaindrop += 100;
  }
  if (key == 's')
  {
    targetRaindrop -= 100;
  }
  if (key == 'e')
  {
    sinkRate += 0.01;
  }
  if (key == 'd')
  {
    sinkRate -= 0.01;
  }
  if (key == 'r')
  {
    cloudHeight += 20;
  }
  if (key == 'f')
  {
    cloudHeight -= 20;
  }
  if (key == 'q')
  {
    if (timer.isRun)
    {
      timer.timerStop();
    } else
    {
      timer = new Timer();
      timer.start();
    }
  }
  if (key == 'c')
  {
    cloudFlags = !cloudFlags;
  }
}
