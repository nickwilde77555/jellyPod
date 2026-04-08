import android.media.MediaPlayer;
import android.net.Uri;
import android.os.Vibrator;
import android.os.VibrationEffect;
import android.content.Context;
import android.app.AlertDialog;
import android.widget.EditText;
import android.content.DialogInterface;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Context;
import android.os.Build;
import java.util.Collections;
import java.util.Comparator;
import java.util.ArrayList;
import java.util.List;
import android.graphics.Bitmap;
import android.app.PendingIntent;
import android.content.Intent;
import android.Manifest;
import android.content.pm.PackageManager;


// --- CONFIG ---
String serverUrl = ""; 
  String username =  "";
  String password =  "";
  String token = "";
String[] info;

MediaPlayer mp;
String desiredId = "";

JSONArray songs;
int songIndex = 0;
int currentIndex = 0;
int lastIndex = 0;

PGraphics pg;
float percentage;
float d;
float lastAngle = 9001;
float wheelAccumulator = 0;
boolean alreadyPressed = false;
boolean beenPressed = false;
int heldFrames = 0;
//0 = song list, 1 = now playing
int screen = 0;
String currentId;
PImage albumArt;
boolean shuffle = false;
boolean shuffleChanged = false;

android.net.wifi.WifiManager.WifiLock wifiLock;

void sortSongs(JSONArray array, final String field) {
  // 1. Convert JSONArray to a Sortable List
  List<JSONObject> list = new ArrayList<JSONObject>();
  for (int i = 0; i < array.size(); i++) {
    list.add(array.getJSONObject(i));
  }

  // 2. Run the Sort
  Collections.sort(list, new Comparator<JSONObject>() {
    @Override
      public int compare(JSONObject a, JSONObject b) {
      String valA = a.getString(field).toLowerCase();
      String valB = b.getString(field).toLowerCase();
      return valA.compareTo(valB);
    }
  }
  );

  // 3. Re-populate the JSONArray
  for (int i = 0; i < list.size(); i++) {
    array.setJSONObject(i, list.get(i));
  }
}

void setIp(String ipp) {
  if (!ipp.startsWith("http")) {
    serverUrl = "http://" + ipp;
  } else {
    serverUrl = ipp;
  }
}

void setUname(String ipp) {
  username = ipp;
}

void setPass(String ipp) {
  password = ipp;
}



void openTextInputIp() {
  getActivity().runOnUiThread(new Runnable() {
    public void run() {
      final EditText input = new EditText(getActivity());
      input.setHint("192.168.1.50:8096");
      new AlertDialog.Builder(getActivity())
        .setTitle("Step 1: Server IP")
        .setView(input)
        .setPositiveButton("Next", new DialogInterface.OnClickListener() {
          public void onClick(DialogInterface dialog, int whichButton) {
            setIp(input.getText().toString());
            openTextInputUname(); // Trigger next
          }
        }).show();
    }
  });
}

void openTextInputUname() {
  getActivity().runOnUiThread(new Runnable() {
    public void run() {
      final EditText input = new EditText(getActivity());
      new AlertDialog.Builder(getActivity())
        .setTitle("Step 2: Username")
        .setView(input)
        .setPositiveButton("Next", new DialogInterface.OnClickListener() {
          public void onClick(DialogInterface dialog, int whichButton) {
            username = input.getText().toString();
            openTextInputPass(); // Trigger next
          }
        }).show();
    }
  });
}

void openTextInputPass() {
  getActivity().runOnUiThread(new Runnable() {
    public void run() {
      final EditText input = new EditText(getActivity());
      input.setInputType(android.text.InputType.TYPE_CLASS_TEXT | android.text.InputType.TYPE_TEXT_VARIATION_PASSWORD);
      new AlertDialog.Builder(getActivity())
        .setTitle("Step 3: Password")
        .setView(input)
        .setPositiveButton("Finish", new DialogInterface.OnClickListener() {
          public void onClick(DialogInterface dialog, int whichButton) {
            password = input.getText().toString();
            // Save and Start
            String[] toSave = {serverUrl, username, password};
            saveStrings("server.txt", toSave);
            thread("initializeJellyfin");
          }
        }).show();
    }
  });
}


void updateNotification(String title, String artist, PImage art) {
  Context context = getActivity().getApplicationContext();
  String channelId = "music_service";

  // 1. Create the Intent that opens the app when the notification is clicked
  Intent intent = new Intent(context, getActivity().getClass());
  PendingIntent pendingIntent = PendingIntent.getActivity(context, 0, intent, PendingIntent.FLAG_IMMUTABLE);

  // 2. Build the notification
  Notification.Builder builder = new Notification.Builder(context, channelId)
    .setContentTitle(title)
    .setContentText(artist)
    .setSmallIcon(android.R.drawable.ic_media_play)
    .setOngoing(true)
    .setContentIntent(pendingIntent) // Opens app on click
    .setAutoCancel(false);

  // 3. Add Album Art if it exists
  if (art != null && art.width > 0) {
    try {
      Bitmap albumBitmap = (Bitmap) art.getNative();
      builder.setLargeIcon(albumBitmap);
    } catch (Exception e) {
      // Fallback if bitmap conversion fails
    }
  }

  // 4. Update the system
  NotificationManager mNotificationManager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
  mNotificationManager.notify(1, builder.build());
}

void startForegroundService() {
  Context context = getActivity().getApplicationContext();
  String channelId = "music_service";

  // 1. Setup the Notification Channel (Required for Android 8.0+)
  if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
    NotificationChannel channel = new NotificationChannel(
      channelId, "Music Playback", 
      NotificationManager.IMPORTANCE_LOW
    );
    NotificationManager manager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
    manager.createNotificationChannel(channel);
  }

  // 2. Build the notification using standard Android system icons
  // Using 'android.R.drawable' ensures we don't need a local 'R' file
  Notification.Builder builder = new Notification.Builder(context, channelId)
    .setContentTitle("Music Player")
    .setContentText("Playing Audio")
    .setSmallIcon(android.R.drawable.ic_media_play) // Default system play icon
    .setOngoing(true);

  // 3. Null-safe check for AlbumArt
  if (albumArt != null && albumArt.width > 0) {
    Bitmap albumBitmap = (Bitmap) albumArt.getNative();
    builder.setLargeIcon(albumBitmap);
  }

  Notification notification = builder.build();

  // 4. Start the service
  getActivity().startForegroundService(new android.content.Intent(context, getActivity().getClass()));
  
  NotificationManager mNotificationManager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
  mNotificationManager.notify(1, notification);
}


void requestNotificationPermission() {
  // Check if we are on Android 13 (API 33) or higher
  if (android.os.Build.VERSION.SDK_INT >= 33) {
    if (getActivity().checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) 
        != PackageManager.PERMISSION_GRANTED) {
      
      // Request the permission using the standard Activity method
      getActivity().requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS}, 101);
    }
  }
}


void settings() {
  if (int(displayWidth*(16.0/9)) < displayHeight) {
  size(displayWidth, int(displayWidth*(16.0/9)), P2D);
  } else {
    size(int(displayWidth*(9.0/16)), displayHeight, P2D);
    print("the size is wack");
  }
}

void setupServer() {
  openTextInputIp();
  openTextInputUname();
  openTextInputPass();
}

void setup() {
  info = loadStrings("server.txt");
  if (info == null || info.length < 3) {
    openTextInputIp(); // This starts the chain
  } else {
    serverUrl = info[0];
    username = info[1];
    password = info[2];
    thread("initializeJellyfin"); // Only start if we have data
  }
  // Flag: Using fullScreen() prevents the 16/9 math bug in Gradle
  //fullScreen();
  orientation(PORTRAIT);
  requestNotificationPermission();
  startForegroundService();
  android.net.wifi.WifiManager wm = (android.net.wifi.WifiManager) getActivity().getSystemService(Context.WIFI_SERVICE);
  wifiLock = wm.createWifiLock(android.net.wifi.WifiManager.WIFI_MODE_FULL_HIGH_PERF, "jellyPodLock");

  pg = createGraphics(floor(width*0.8), floor(width*0.8), P2D);

  // Flag: Run networking on a thread to avoid the MainThread exception
  //thread("initializeJellyfin");
}

void draw() {
  background(0);
  fill(255);
  //textSize(40);
  // 904 is the magic pixel width for the Fold5 Cover Screen
  float fold5Width = 904.0; 
  float dynamicFontSize = 40.0 * (width / fold5Width);
  
  // Apply to main canvas
  textSize(dynamicFontSize);
  //text("Jellyfin MVP", 50, 80);
  //text("Status: " + (token.equals("") ? "Connecting..." : "Ready"), 50, 150);

  /*
  if (!desiredId.equals("")) {
   fill(0, 255, 0);
   text("Found Cicada!", 50, 250);
   text("Tap to Stream", 50, 320);
   }
   */
   //text(alreadyPressed? "TRUE" : "FALSE" + heldFrames, 50, 50);
  if (!token.equals("") && songs != null) {
    rect(width*0.1, height*0.1, width*0.8, width*0.8);
    if (screen == 0) {
      pg.beginDraw();
      pg.textSize(dynamicFontSize);
      pg.background(255);
      pg.fill(0);
      pg.pushMatrix();
      pg.translate(width*0.02, height*0.02);
      if (currentIndex >= songs.size()) {
        currentIndex = songs.size()-1;
      }
      if (currentIndex < 0) {
        currentIndex = 0;
      }
      //fill(0);
      float maxDistance = width*0.8 / (dynamicFontSize*1.2);
      int maxSongs = floor(maxDistance);
      float maxTranslation = (-(dynamicFontSize*1.2)*songs.size()) + ((dynamicFontSize*1.2) * maxSongs);
      if (songs.size() > maxSongs) {
        if (-(dynamicFontSize*1.2)*currentIndex < maxTranslation) {
          pg.translate(0, maxTranslation);
        } else {
          pg.translate(0, -(dynamicFontSize*1.2)*currentIndex);
        }
      }
      for (int i = 0; i < songs.size(); i++) {
        pg.fill(0);
        JSONObject item = songs.getJSONObject(i);
        String name = item.getString("Name");
        if (currentIndex == i) {
          pg.pushMatrix();
          pg.fill(50, 50, 200);
          pg.rect(-width, (-height*0.02) + (dynamicFontSize*1.2)*i, width*2, dynamicFontSize);
          pg.popMatrix();
          pg.fill(255);
        }
        pg.text(name, 0, i*(dynamicFontSize*1.2));
      }

      pg.popMatrix();
      pg.endDraw();
      image(pg, width*0.1, height*0.1, pg.width, pg.height);
    }
    if (screen == 1) {
      pg.beginDraw();
      pg.background(255);
      try {
        pg.image(albumArt, pg.width*0.25, pg.height*0.05, pg.width*0.5, pg.width*0.5);
      }
      catch (NullPointerException e) {
      }

      pg.fill(0);
      JSONObject item = songs.getJSONObject(songIndex);
      String name = item.getString("Name");
      pg.textAlign(CENTER);
      pg.text(name, pg.width*0.5, pg.height*0.7);
      // 1. Get a safe string (defaults to empty if missing)
      String artist = item.isNull("AlbumArtist") ? "" : item.getString("AlbumArtist");

      // 2. If AlbumArtist is empty, try the first entry in the Artists array
      if (artist.equals("") && !item.isNull("Artists") && item.getJSONArray("Artists").size() > 0) {
        artist = item.getJSONArray("Artists").getString(0);
      }
      pg.text(artist, pg.width * 0.5, pg.height * 0.75);
      pg.textAlign(LEFT);
      
      if (shuffle) {
        pg.text("S", pg.width*0.1, pg.height*0.9125);
      }
      
      try {
  // 1. Double check mp exists AND is actually playing/active
  if (mp != null && mp.isPlaying()) { 
    int maxDuration = mp.getDuration();
    int currentPosition = mp.getCurrentPosition();
    
    // 2. Prevent division by zero if the song just started
    if (maxDuration > 0) {
      percentage = currentPosition / (float)maxDuration;
      
      pg.fill(255);
      pg.rect(pg.width * 0.15, pg.height * 0.85, pg.width * 0.55, pg.height * 0.1);
      
      pg.fill(50, 50, 200);
      pg.rect(pg.width * 0.15, pg.height * 0.85, (pg.width * 0.55) * percentage, pg.height * 0.1);
      pg.fill(0);
      float secondsPosition = currentPosition / 1000;
      int minutesPosition = floor(secondsPosition / 60);
      secondsPosition = int(secondsPosition % 60);
      String posit = "" + int(secondsPosition);
      if (posit.length() < 2) {
        posit = "0" + posit;
      }
      pg.text(minutesPosition + ":" + posit, pg.width * 0.75, pg.height * 0.90);
      secondsPosition = maxDuration / 1000;
      minutesPosition = floor(secondsPosition / 60);
      secondsPosition = int(secondsPosition % 60);
      posit = "" + int(secondsPosition);
      if (posit.length() < 2) {
        posit = "0" + posit;
      }
      pg.text(minutesPosition + ":" + posit, pg.width * 0.75, pg.height * 0.95);
    }
  } else if (percentage > 0) {
    pg.fill(255);
      pg.rect(pg.width * 0.15, pg.height * 0.85, pg.width * 0.55, pg.height * 0.1);
      
      pg.fill(50, 50, 200);
      pg.rect(pg.width * 0.15, pg.height * 0.85, (pg.width * 0.55) * percentage, pg.height * 0.1);
      pg.text("PAUSE", pg.width * 0.75, pg.height * 0.925);
  }
} catch (Exception e) { 
  // 3. Catch ALL exceptions (like IllegalStateException) so the draw loop keeps running
  // println("Progress bar sync error: " + e.getMessage()); 
}
      
      pg.endDraw();
      image(pg, width*0.1, height*0.1, pg.width, pg.width);
    }


    drawWheel();
    if (mousePressed) {
      heldFrames++;
      mousePress();
    } else if (heldFrames > 0) {
      if (beenPressed) {
        if (lastAngle < 9000) {
          print(lastAngle);
        }
        if (abs(lastAngle + HALF_PI) < QUARTER_PI && heldFrames < 99990) {
          if (screen == 1) {
            screen = 0;
          } else if (screen == 0) {
            screen = 1;
          }
        }
        else if (abs(lastAngle - HALF_PI) < QUARTER_PI && heldFrames < 99990) {
          if (mp != null && mp.isPlaying()) {
            mp.pause();
          } else if (mp != null && !mp.isPlaying()) {
            mp.start();
          }
        }
        
        else if (abs(lastAngle) < QUARTER_PI && heldFrames < 99990) {
          if (!shuffle) {
            currentIndex++;
            println(" notshuffled");
          } else {
            println("shuffle");
            lastIndex = currentIndex;
            currentIndex = int(random(songs.size()));
          }
          playSong();
          println("UNEXPECTED BITCH 1");
        } else if (abs(lastAngle) > 3 * QUARTER_PI && heldFrames < 99990 && d <= (width*0.5)/2) {
          //this shit keeps misfiring so hard im debating fucking removing it.
          if (!shuffle) {
            currentIndex--;
          } else {
            currentIndex = lastIndex;
          }
          playSong();
          println("POSSIBLY EXPECTED BITCH WTF");
        }
      }
      wheelAccumulator = 0;
      lastAngle = 9001;
      alreadyPressed = false;
      beenPressed = false;
      heldFrames = 0;
      shuffleChanged = false;
      //print("Debounce????");
    }
  }
}

void initializeJellyfin() {
  authenticate();
  fetchSongs();
}

void authenticate() {
  try {
    java.net.URL url = new java.net.URL(serverUrl + "/Users/AuthenticateByName");
    java.net.HttpURLConnection conn = (java.net.HttpURLConnection) url.openConnection();
    conn.setRequestMethod("POST");
    conn.setRequestProperty("Content-Type", "application/json");
    conn.setRequestProperty("X-Emby-Authorization", "MediaBrowser Client=\"iPod\", Device=\"Fold5\", DeviceId=\"1\", Version=\"1\"");
    conn.setDoOutput(true);

    String json = "{\"Username\":\"" + username + "\", \"Pw\":\"" + password + "\"}";
    conn.getOutputStream().write(json.getBytes());

    if (conn.getResponseCode() == 200) {
      String resultStr = trim(join(loadStrings(conn.getInputStream()), ""));
      JSONObject result = parseJSONObject(resultStr);
      token = result.getString("AccessToken");
      println("Login Success: " + token);
    }
  }
  catch (Exception e) {
    println("Login Error: " + e.getMessage());
  }
}

void fetchSongs() {
  if (token.equals("")) return;
  try {
    String songUrl = serverUrl + "/Items?Recursive=true&IncludeItemTypes=Audio&api_key=" + token;
    JSONObject library = loadJSONObject(songUrl);
    JSONArray items = library.getJSONArray("Items");
    songs = items;
    sortSongs(songs, "Name");
    /*
    for (int i = 0; i < items.size(); i++) {
     JSONObject item = items.getJSONObject(i);
     String name = item.getString("Name");
     if (name.toLowerCase().contains("cicada")) {
     desiredId = item.getString("Id");
     println("Target acquired: " + name);
     }
     }
     */
  }
  catch (Exception e) {
    println("Fetch Error: " + e.getMessage());
  }
}



void mousePress() {
  if (heldFrames == 1) {
    beenPressed = true;
  }
  float centerX = width*0.5;
  float centerY = height*0.8;
  d = dist(mouseX, mouseY, centerX, centerY);
  float outerRadius = (width*0.5)/2;
  float innerRadius = (width*0.2)/2;
  if (d <= outerRadius && d >= innerRadius) {
    alreadyPressed = true;
    float curAngle = atan2(mouseY-centerY, mouseX-centerX);
    if (lastAngle < 9000) {
      float delta = curAngle - lastAngle;
      if (delta > PI) delta -= TWO_PI;
      if (delta < -PI) delta += TWO_PI;
      wheelAccumulator += delta;
      if (wheelAccumulator > 0.15) {
        currentIndex++;
        beenPressed = false;
        wheelAccumulator -= 0.15;
        triggerTick();
      }

      if (wheelAccumulator < -0.15) {
        currentIndex--;
        beenPressed = false;
        wheelAccumulator += 0.15;
        triggerTick();
      }
    }

    lastAngle = curAngle;
  } else if (d <= innerRadius && !alreadyPressed && ((mp == null) || (songIndex != currentIndex))) {
    println("FRESH START");
    beenPressed = false;
    JSONObject item = songs.getJSONObject(currentIndex);
    String id = item.getString("Id");
    currentId = id;
    thread("playSong");
    screen = 1;
    alreadyPressed = true;
    //heldFrames+=99999;
  } else if (d <= innerRadius && !alreadyPressed && mp.isPlaying() && screen == 1) {
    //heldFrames+=99999;
    beenPressed = false;
    mp.pause();
    alreadyPressed = true;
  } else if (d <= innerRadius && !alreadyPressed && screen == 0 && songIndex == currentIndex) {
    beenPressed = false;
    //heldFrames+=99999;
    screen = 1;
    alreadyPressed = true;
  } else if (d <= innerRadius && !alreadyPressed && !mp.isPlaying() && currentIndex == songIndex) {
    beenPressed = false;
    //heldFrames+=99999;
    println("NOT THIS BITCH?");
    mp.start();
    alreadyPressed = true;
  }
  
  if (d <= innerRadius && heldFrames > frameRate &! shuffleChanged && screen == 1) {
    beenPressed = false;
    shuffle = !shuffle;
    shuffleChanged = true;
  }
}

void playSong() {
  if (!wifiLock.isHeld()) wifiLock.acquire();
  songIndex = currentIndex;
  JSONObject item = songs.getJSONObject(currentIndex);
  String id = item.getString("Id");
  String streamUrl = serverUrl + "/Audio/" + id + "/stream?static=true&api_key=" + token;
  try {
    if (mp != null) {
      mp.stop();
      mp.release();
    }
    mp = new MediaPlayer();
    mp.setWakeMode(getActivity(), android.os.PowerManager.PARTIAL_WAKE_LOCK);
    // Using getActivity() is often more stable than this.getContext() for Gradle
    mp.setDataSource(getActivity(), Uri.parse(streamUrl));
    mp.prepareAsync();
    mp.setOnPreparedListener(new MediaPlayer.OnPreparedListener() {
      public void onPrepared(MediaPlayer player) {
        player.start();
      }
    }
    );

    mp.setOnCompletionListener(new MediaPlayer.OnCompletionListener() {
      public void onCompletion(MediaPlayer player) {
        println("Song completed");
        if (!shuffle) {
          currentIndex++;
        } else {
          lastIndex = currentIndex;
          currentIndex = int(random(songs.size()));        
        }
        if (currentIndex >= songs.size()) {
          currentIndex = 0;
        }
        JSONObject nextSong = songs.getJSONObject(currentIndex);
        String nextId = nextSong.getString("Id");
        currentId = nextId;
        println("Playing next song...");
        playSong();
        println("Next song played");
      }
    }
    );
  }
  catch (Exception e) {
    println("Playback Error: " + e.getMessage());
  }

  thread("loadPicture");
}

void loadPicture() {
  println("loading new picture");
  currentId = songs.getJSONObject(songIndex).getString("Id");
  String albumURL = serverUrl + "/Items/" + currentId + "/Images/Primary?fillHeight=300&fillWidth=300&quality=90";
  albumArt = loadImage(albumURL);
  JSONObject item = songs.getJSONObject(currentIndex);
  String name = item.getString("Name");
  String artist = item.isNull("AlbumArtist") ? "Unknown Artist" : item.getString("AlbumArtist");
  println("updating notification");
  updateNotification(name, artist, albumArt);
  println("picture loaded successfully");
}

void drawWheel() {
  fill(150);
  ellipseMode(CENTER);
  ellipse(width*0.5, height*0.8, width*0.5, width*0.5);
  fill(0);
  ellipse(width*0.5, height*0.8, width*0.2, width*0.2);
}

void triggerTick() {
  Vibrator v = (Vibrator) getContext().getSystemService(Context.VIBRATOR_SERVICE);
  if (v != null && v.hasVibrator()) {
    v.vibrate(VibrationEffect.createPredefined(VibrationEffect.EFFECT_CLICK));
  }
  //println("triggering tick");
}
