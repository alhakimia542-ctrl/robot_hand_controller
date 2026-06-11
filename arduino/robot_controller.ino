#include <Servo.h>
#include <SoftwareSerial.h>

// ==========================================
// 1. تعريف المنافذ (Pins Configuration)
// ==========================================
SoftwareSerial BTSerial(10, 11); // RX, TX

// منافذ السيرفو
const int basePin = 8;
const int liftPin = 9;
const int gripPin = 7;
const int extendPin = 6;

// منافذ درايفر المحركات L298N
const int motorRightIN1 = A0; 
const int motorRightIN2 = A1; 
const int motorLeftIN3 = A2;  
const int motorLeftIN4 = A3;  

// منافذ التحكم بالسرعة (PWM)
const int enaPin = 3; // سرعة المحرك الأيمن
const int enbPin = 5; // سرعة المحرك الأيسر

// إعدادات السرعة (من 0 إلى 255)
int normalSpeed = 130;   // سرعة آمنة للحركة الأمامية والدوران منعاً للانقلاب
int backwardSpeed = 180; // سرعة أعلى نسبياً لإعطاء عزم كافٍ للمحركين عند الرجوع

// ==========================================
// 2. كائنات السيرفو وزوايا المنتصف والبداية
// ==========================================
Servo baseServo;
Servo liftServo;
Servo gripServo;
Servo extendServo;

int baseAngle = 90;   // منتصف القاعدة
int liftAngle = 62;   // منتصف الرفع
int extendAngle = 60; // منتصف المد
int gripAngle = 10;   // يبدأ من وضعية الفتح الجديدة التي عايرتها يدوياً لأقصى اليسار

String currentCommand = "HOLD";

void setup() {
  Serial.begin(9600);
  BTSerial.begin(9600);
  
  baseServo.attach(basePin);
  liftServo.attach(liftPin);
  gripServo.attach(gripPin);
  extendServo.attach(extendPin);
  
  // توجيه المحركات لوضعيات البداية المستقرة (تم تصحيح الخطأ هنا ✔️)
  baseServo.write(baseAngle);
  liftServo.write(liftAngle);
  extendServo.write(extendAngle); 
  gripServo.write(gripAngle);

  // تهيئة منافذ العجلات
  pinMode(motorRightIN1, OUTPUT);
  pinMode(motorRightIN2, OUTPUT);
  pinMode(motorLeftIN3, OUTPUT);
  pinMode(motorLeftIN4, OUTPUT);
  
  pinMode(enaPin, OUTPUT);
  pinMode(enbPin, OUTPUT);

  stopMotors();
  Serial.println("🤖 المنظومة جاهزة تماماً ومطابقة للمعايرة الميدانية الأخيرة!");
}

void loop() {
  if (BTSerial.available()) {
    String incoming = BTSerial.readStringUntil('\n');
    incoming.trim();
    if (incoming.length() > 0) {
      currentCommand = incoming;
      Serial.println("الأمر النشط: " + currentCommand);
    }
  }

  executeCommand();
  delay(15); 
}

// ==========================================
// 3. خوارزمية التحكم والتنفيذ للأوامر
// ==========================================
void executeCommand() {
  
  // --- التحكم بالحركة الفيزيائية للقاعدة (العجلات) ---
  if (currentCommand == "DC_FORWARD") {
    moveForward();
  } 
  else if (currentCommand == "DC_BACKWARD") {
    moveBackward(); // ستعمل هنا التغذية الإضافية للعزم
  } 
  else if (currentCommand == "ROTATE_RIGHT") {
    rotateRight(); 
  } 
  else if (currentCommand == "ROTATE_LEFT") {
    rotateLeft();  
  } 
  else if (currentCommand == "HOLD") {
    stopMotors();
  }

  // --- التحكم بحركات الذراع (السيرفوهات الثابتة) ---
  if (currentCommand == "BASE_RIGHT") {
    if (baseAngle > 0) { baseAngle -= 1; baseServo.write(baseAngle); }
  } 
  else if (currentCommand == "BASE_LEFT") {
    if (baseAngle < 180) { baseAngle += 1; baseServo.write(baseAngle); }
  } 
  
  else if (currentCommand == "LIFT_UP") {
    if (liftAngle > 20) { liftAngle -= 1; liftServo.write(liftAngle); }
  } 
  else if (currentCommand == "LIFT_DOWN") {
    if (liftAngle < 105) { liftAngle += 1; liftServo.write(liftAngle); }
  } 
  
  else if (currentCommand == "EXTEND") {
    if (extendAngle > 15) { extendAngle -= 1; extendServo.write(extendAngle); }
  } 
  else if (currentCommand == "RETRACT") {
    if (extendAngle < 105) { extendAngle += 1; extendServo.write(extendAngle); }
  } 
  
  // التحكم بالمقبض بناءً على تصفيرك اليدوي الجديد لأقصى اليسار
  else if (currentCommand == "GRIP_OPEN") {
    gripAngle = 10; // أقصى اليسار مع هامش أمان صامت لمنع الزنة
    gripServo.write(gripAngle);
  } 
  else if (currentCommand == "GRIP_CLOSED") {
    gripAngle = 45; // يتحرك نحو اليمين ليغلق الفكين (اضبط هذا الرقم بدقة حسب الحاجة)
    gripServo.write(gripAngle);
  }
}

// ==========================================
// 4. دوال تشغيل العجلات المتطابقة ميكانيكياً وطاقةً
// ==========================================

void moveForward() {
  // تطبيق السرعة العادية المستقرة للأمام
  analogWrite(enaPin, normalSpeed);
  analogWrite(enbPin, normalSpeed);
  
  digitalWrite(motorRightIN1, LOW);
  digitalWrite(motorRightIN2, HIGH);
  digitalWrite(motorLeftIN3, LOW);
  digitalWrite(motorLeftIN4, HIGH);
}

void moveBackward() {
  // تطبيق سرعة أعلى (عزم أقوى) للتغلب على مقاومة الرجوع للمحركين معاً
  analogWrite(enaPin, backwardSpeed);
  analogWrite(enbPin, backwardSpeed);
  
  digitalWrite(motorRightIN1, HIGH);
  digitalWrite(motorRightIN2, LOW);
  digitalWrite(motorLeftIN3, HIGH);
  digitalWrite(motorLeftIN4, LOW);
}

void rotateRight() {
  analogWrite(enaPin, normalSpeed);
  analogWrite(enbPin, normalSpeed);
  
  digitalWrite(motorRightIN1, HIGH);
  digitalWrite(motorRightIN2, LOW);
  digitalWrite(motorLeftIN3, LOW);
  digitalWrite(motorLeftIN4, HIGH);
}

void rotateLeft() {
  analogWrite(enaPin, normalSpeed);
  analogWrite(enbPin, normalSpeed);
  
  digitalWrite(motorRightIN1, LOW);
  digitalWrite(motorRightIN2, HIGH);
  digitalWrite(motorLeftIN3, HIGH);
  digitalWrite(motorLeftIN4, LOW);
}

void stopMotors() {
  digitalWrite(motorRightIN1, LOW);
  digitalWrite(motorRightIN2, LOW);
  digitalWrite(motorLeftIN3, LOW);
  digitalWrite(motorLeftIN4, LOW);
}