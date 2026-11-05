/*
  SILO DE ARROZ - Arduino Uno + HC-SR04

  VCC  -> 5V
  GND  -> GND
  TRIG -> D9
  ECHO -> D10

  Serial 115200:

  D,sequencia,millis,distancia_cm
  E,sequencia,millis,SEM_ECO

  D = houve medicao de duracao do pulso
  E = timeout, sem pulso completo

  Os limites fisicos e filtros
  ficam no Processing.
*/

const byte PINO_TRIG = 9;
const byte PINO_ECHO = 10;

const unsigned long INTERVALO_MS = 90;
const unsigned long TIMEOUT_US = 25000UL;

unsigned long ultimaAmostra = 0;
unsigned long sequencia = 0;

void setup() {
  pinMode(PINO_TRIG, OUTPUT);
  pinMode(PINO_ECHO, INPUT);

  digitalWrite(PINO_TRIG, LOW);

  Serial.begin(115200);
}

float distanciaCm() {
  digitalWrite(PINO_TRIG, LOW);
  delayMicroseconds(3);

  digitalWrite(PINO_TRIG, HIGH);
  delayMicroseconds(10);
  digitalWrite(PINO_TRIG, LOW);

  unsigned long duracao =
    pulseIn(PINO_ECHO, HIGH, TIMEOUT_US);

  if (duracao == 0) {
    return -1.0;
  }

  return duracao * 0.0343 / 2.0;
}

void loop() {
  if (millis() - ultimaAmostra < INTERVALO_MS) {
    return;
  }

  ultimaAmostra = millis();

  float cm = distanciaCm();
  sequencia++;

  if (cm < 0) {
    Serial.print("E,");
    Serial.print(sequencia);
    Serial.print(',');
    Serial.print(millis());
    Serial.println(",SEM_ECO");

    return;
  }

  Serial.print("D,");
  Serial.print(sequencia);
  Serial.print(',');
  Serial.print(millis());
  Serial.print(',');
  Serial.println(cm, 2);
}