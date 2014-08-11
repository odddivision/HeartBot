import processing.serial.*;
import controlP5.*;


ControlP5 cp5;
String props = "bot.properties";

PFont font;
boolean drawingInProgress = false;


boolean useSensor = true;      // ATTENTION!!!   Set this to false to disable the sensor altogether
boolean useHektor = true;      // MORE ATTENTION! false to disable hektorbot
boolean useDualPen = true;

JSONObject persist;

// Global Hektor speed -- used whenever coords are put into the Hektor queue by the "moves" ArrayList
float platformSpeed = 1.0;

// Global twitch variales. 
boolean doTwitch;
String twitchStyle;
float twitchAngle;
float twitchAmount;

ArrayList<String> commands = new ArrayList<String>(); // meta-command strings
ArrayList<PVector> moves = new ArrayList<PVector>();  // platform move commands (because the tinyg can only hold 20, this holds the rest)


RadioButton moduleChooser;

// ---------------------------------------------------------------
void setup() {
  hektorSetup(); // takes 20-30 seconds!
  dualPenSetup();
  sensorSetup();

  size(700, 600);  // Stage size
  frameRate(100);  
  smooth();

  registerPre(this);
  font = loadFont("HelveticaNeue-24.vlw");
  textFont(font, 14);

  cp5 = new ControlP5(this);
  moduleChooser = cp5.addRadioButton("moduleChooser")
    .setPosition(20, 50)
      .setSize(40, 20)
        .setColorForeground(color(120))
          .setColorActive(color(255))
            .setColorLabel(color(255))
              .setItemsPerRow(5)
                .setSpacingColumn(50)
                  .addItem("circles", 1)
                    .addItem("fishbone", 2)
                      .addItem("starburst", 3)
                        .addItem("triangles", 4)
                          .addItem("vortex", 5)
                            ;
                            
  cp5.loadProperties(props);

  try {
    persist = loadJSONObject("persist.json");
  } 
  catch(Exception e) {
    persist = new JSONObject();
  }

  starburstSetup();
  vortexSetup();

  println(Serial.list());
}

void controlEvent(ControlEvent theEvent) {
  if (theEvent.isFrom(moduleChooser)) {
    println("Saving Properties to "+props);
    cp5.saveProperties(props);
  }
}

// ---------------------------------------------------------------
void onBeatUp() {
  buttonLightOn();
}

// ---------------------------------------------------------------
void onBeatDown() {
  buttonLightOff();
}

// ---------------------------------------------------------------
void pre() {

  sensorUpdate();
  hektorUpdate();

  if (doTwitch) {
    if ( twitchStyle == "vortex") {
      vortexTwitch();
    } else if (twitchStyle == "starburst") {
      starburstTwitch();
    } else {
      println("twitch style unknown: "+twitchStyle);
    }
  }

  // If there is room in the Hektor queue, add some stuff from the moves ArrayList
  if (hektorQueueLength < 5 && moves.size() > 0) {
    movePlatform(moves.get(0).x, moves.get(0).y, platformSpeed);
    moves.remove(0);
  }

  // If there are any commands to process, process them.
  if (commands.size() > 0) {
    String cmd = commands.get(0);
    boolean cmdFinished = true;

    if (cmd=="wait for queue" || cmd=="null") print('.');
    else println(cmd);

    if (cmd == "pen1 up") {
      dualPenSetPen(1, false);
    } else if (cmd == "pen2 up") {
      dualPenSetPen(2, false);
    } else if (cmd == "pen1 down") {
      dualPenSetPen(1, true);
    } else if (cmd == "pen2 down") {
      dualPenSetPen(2, true);
    } else if (cmd == "goto start") {
      moves.add( start );
    } else if (cmd == "goto end") {
      moves.add( end );
    } else if (cmd == "goto home") {
      moves.add( new PVector(0.5, 0) );
    } else if ( cmd == "fishbone prep circle" ) {
      fishbonePrepCircle();
    } else if (cmd == "circle") {
      makeCircle();
    } else if ( cmd == "wait for queue") {
      cmdFinished = (hektorQueueLength==0 && moves.size()==0);
    } else if ( cmd == "start drawing") {
      drawingInProgress = true;
    } else if ( cmd == "end drawing") {
      drawingInProgress = false;
    } else if ( cmd == "start twitch") {
      doTwitch = true;
    } else if ( cmd == "stop twitch") {
      doTwitch = false;
    } else if ( cmd == "pen1 home") {
      dualPenHome(1);
    } else if ( cmd == "pen2 home") {
      dualPenHome(2);
    } else if ( cmd == "fishbone set radius") {
      fishboneSetRadius();
    } else if ( cmd == "full speed") {
      platformSpeed = 1.0;
    } else if ( cmd == "sun speed" ) {
      setSunSpeed();
    } else if ( cmd == "goto north" ) {
      moves.add(north);
    } else if ( cmd == "goto south" ) {
      moves.add(south);
    } else if ( cmd == "goto east" ) {
      moves.add(east);
    } else if ( cmd == "goto west" ) {
      moves.add(west);
    } else if ( cmd == "make triangle" ) {
      makeTriangle();
    } else if ( cmd == "triangles speed" ) {
      triangleSetSpeed();
    } else if ( cmd == "triangles prep") {
      trianglePrep();
    } else if ( cmd == "circles update") {
      circlesUpdate();
    } else if ( cmd == "circles prep") {
      circlesPrep();
    } else if ( cmd == "starburst speed") {
      starburstSpeed();
    } else if ( cmd == "starburst draw line") {
      starburstDrawLine();
    } else if ( cmd == "goto center") {
      moves.add( new PVector(0.5, 0.5) );
    } else if ( cmd ==  "starburst increment" ) {
      starburstIncrement();
    } else if ( cmd == "vortex increment" ) {
      vortexIncrement();
    } else if ( cmd == "vortex prep" ) {
      vortexPrep();
    } else if ( cmd == "vortex draw" ) {
      vortexDraw();
    } else if ( cmd == "starburst circle" ) {
      starburstCircle();
    } else if (cmd == "starburst circle prep") {
      starburstCirclePrep();
    } else {
      println("WARNING: unknown command"+cmd);
    }

    if (cmdFinished)  commands.remove(0);
  }
}

// ---------------------------------------------------------------
void draw() {
  background(51);
  fill(#FFFFFF);
  noStroke();

  String msg[] = {
    "FrameRate = "+int(frameRate), 
    "drawingInProgress = " + (drawingInProgress ? "YES" : "NO"), 
    "BPM = "+BPM, 
    "IBI = "+IBI, 
    "Signal = "+Sensor, 
    "Mean = "+Mean, 
    "StdDev = "+StdDev, 
    "StdDevThreshCounter = "+StdDevThreshCounter, 
    "hektorQueueLength = "+hektorQueueLength, 
    "commands.size() = "+commands.size(), 
    "moves.size() = " + moves.size(), 
    "current command = " + (commands.size()>0 ? commands.get(0) : ""), 
    "twitchAngle = " + twitchAngle, 
    "twitchAmount = " + twitchAmount
  };
  int ystart = 100;
  for (int i=0; i<msg.length; i++) {
    text(msg[i], 10, ystart+(i*16));
  }

  drawSignal();
  drawHeart(width-30, height/2);
}


// ---------------------------------------------------------------
void mousePressed() {
  //  float x = map(mouseX, 0, width, 0, 1);
  //  float y = map(mouseY, 0, height, 0, 1);
  //  movePlatform(x, y);
}

// ---------------------------------------------------------------
void mouseReleased() {
}


// ---------------------------------------------------------------
void keyPressed() {

  switch(key) {
  case 'q':
    hektorRequestQueueReport();
    break;

  case '0':
    buttonLightOff();
    break;

  case '1':
    buttonLightOn();
    break;

  case 'I':
    hektorJogRaw(0, -1);
    break;
  case 'J':
    hektorJogRaw(-1, 0);
    break;
  case 'K':
    hektorJogRaw(0, 1);
    break;
  case 'L':
    hektorJogRaw(1, 0);
    break;

  case 'i':
    hektorJogRaw(0, -5);
    break;
  case 'j':
    hektorJogRaw(-5, 0);
    break;
  case 'k':
    hektorJogRaw(0, 5);
    break;
  case 'l':
    hektorJogRaw(5, 0);
    break;

  case 'p':
    dualPenSetPen(2, true);
    break;

  case 'o':
    dualPenSetPen(2, false);
    break;

  case 'H':
    hektorSetHome();
    break;

  case 'g':
    dualPenHome(1);
    dualPenHome(2);
    break;


  case '+':
    dualPenSetPen(1, true);
    dualPenSetPen(2, true);
    break;

  case '-':
    dualPenSetPen(1, false);
    dualPenSetPen(2, false);
    break;

  case '`':
    hektorMotorsOff();
    break;


  default:
    break;
  }


  // hektor bot moving 
  if (key==CODED) {
    switch(keyCode) {
    case UP:
      hektorJog(0, -1);
      break;
    case DOWN:
      hektorJog(0, 1);
      break;
    case LEFT:
      hektorJog(-1, 0);
      break;
    case RIGHT:
      hektorJog(1, 0);
      break;
    }
  }
}

//----------------------------------------------------
void serialEvent(Serial port) {
  try {
    String inData = port.readStringUntil('\n');
    if (inData==null) return;
    inData = trim(inData);
    if (inData.length()==0) return;

    if (port==tinyg) {
      hektorSerialEvent(inData);
    } else if (useSensor && port==sPort) {
      sensorSerialEvent(inData);
    }
  } 
  catch (Exception e) {
    println("Problem reading from serial");
    e.printStackTrace();
  }
}





/*************************************
 ╔╦╗┌─┐┌┬┐┌─┐╔═╗┌─┐┌┬┐┌┬┐┌─┐┌┐┌┌┬┐┌─┐
 ║║║├┤  │ ├─┤║  │ │││││││├─┤│││ ││└─┐
 ╩ ╩└─┘ ┴ ┴ ┴╚═╝└─┘┴ ┴┴ ┴┴ ┴┘└┘─┴┘└─┘
 *************************************/


// TO DO: get rid of these -- they are confusing
// Variables shared by several Modules
PVector start = new PVector();
PVector end = new PVector();


// TO DO: get rid of these -- they are confusing
// ---------------------------------------------------------------
// Function used by several modules
float circleRadius;
PVector circleCenter = new PVector();
void makeCircle() {
  float inc = radians(360) / 40.0;
  for (float angle = 0; angle < radians (360)+inc; angle+=inc) {
    PVector p = new PVector();
    p.x = circleCenter.x + cos(angle) * circleRadius;
    p.y = circleCenter.y + sin(angle) * circleRadius;
    moves.add( p );
  }
}



// ---------------------------------------------------------------
// x, y in range 0.0 to 1.0
void movePlatform(float x, float y, float speed) {
  float platformX = x * 72 + 22;
  float platformY = y * 72 + 22;
  //println("Hektor to "+x+", "+y + ", => " + platformX + ", " + platformY + " - enabled? " + useHektor);
  hektorGotoXY(platformX, platformY, speed);
}

// ---------------------------------------------------------------
void movePlatform(float x, float y) {
  movePlatform(x, y, 1.0);
}

