#define PHOTO_PIN A0
#define DHT_PIN 2
#define DHT11_RETRY_DELAY 1000

unsigned long last_read_time = 0;
byte hI;
byte hF;
byte tI;
byte tF;


void setup()
{
  Serial.begin(9600);
}

void loop()
{
  int err, photo;
  float temp;
  byte humid;
  photo = analogRead(PHOTO_PIN);
  err = read(humid, temp);
  if(err == 0)
  {
    Serial.write(126);
    Serial.write(tI);
    Serial.write(tF);
    Serial.write(hI);
    Serial.write(hF);
    Serial.write(photo >> 8);
    Serial.write((byte)photo);
    Serial.write(127);
  }
  else
  {
  }

  delay(DHT11_RETRY_DELAY * 2);
}

int read(byte& humidity, float& temperature) {
  long temp;

  if((millis()-last_read_time<DHT11_RETRY_DELAY)&&last_read_time!=0)  return -1;
  pinMode(DHT_PIN,OUTPUT);
  digitalWrite(DHT_PIN, LOW);
  delay(18);
  digitalWrite(DHT_PIN, HIGH);
  pinMode(DHT_PIN,INPUT);

  if((temp = waitFor(LOW, 40))<0)  return 1; //waiting for DH11 ready
  if((temp = waitFor(HIGH, 90))<0) return 1; //waiting for first LOW signal(80us)
  if((temp = waitFor(LOW, 90))<0)  return 1; //waiting for first HIGH signal(80us)

  hI=readByte();
  hF=readByte();
  tI=readByte();
  tF=readByte();
  byte cksum=readByte();
  if(hI+hF+tI+tF!=cksum)
    return 4;

  humidity=(float)hI+(((float)hF)/100.0F);
  temperature=(float)tI+(((float)tF)/100.0F);
  last_read_time=millis();
  return 0;
}

unsigned long waitFor(uint8_t target, unsigned long time_out_us) {
  unsigned long start=micros();
  unsigned long time_out=start+time_out_us;
  while(digitalRead(DHT_PIN)!=target)
  {
    if(time_out<micros()) return -1;
  }
  return micros()-start;
}

void waitFor(uint8_t target) {
  while(digitalRead(DHT_PIN)!=target);
}

byte readByte() {
  int i=0;
  byte ret=0;
  for(i=7;i>=0;i--)
  {
    waitFor(HIGH); //wait for 50us in LOW status
    delayMicroseconds(30); //wait for 30us
    if(digitalRead(DHT_PIN)==HIGH) //if HIGH status lasts for 30us, the bit is 1;
    {
      ret|=1<<(i);
      waitFor(LOW); //wait for rest time in HIGH status.
    }
  }
  return ret;
}
