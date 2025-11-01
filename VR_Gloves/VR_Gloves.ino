#include <SoftwareSerial.h>
#include <Servo.h>

SoftwareSerial BLE_Serial(2, 3);

int previousPos = 180;

Servo fingers;

void setup() {
  Serial.begin(9600);
  BLE_Serial.begin(9600);
  pinMode(13, OUTPUT);
  fingers.write(180);
  digitalWrite(6, HIGH);
  fingers.attach(9);
}

void loop() {
  if (BLE_Serial.available()) {
    int i = BLE_Serial.read();

    if (i == 0) { //inverted
      int pos = 180;

      if (pos != previousPos) {
        fingers.write(180);
      }

      previousPos = pos;
      
      digitalWrite(13, LOW);
    } else {
      int pos = 0;
      
      if (pos != previousPos) {
        fingers.write(0);
      }

      previousPos = pos;
      
      digitalWrite(13, HIGH);
    }
  }
}
