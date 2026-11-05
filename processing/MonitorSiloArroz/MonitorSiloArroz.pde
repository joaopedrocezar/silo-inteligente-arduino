
import processing.serial.*;
import java.util.ArrayDeque;
import java.util.Arrays;
import java.util.Random;
import java.io.File;

/*
  SILO DE ARROZ - PROCESSING 4

  Arduino Uno + HC-SR04
  Serial: 115200 baud

  METODOS:
  0 - Bruta
  1 - Mediana 3
  2 - Mediana 5
  3 - Media movel 3
  4 - Media movel 5
  5 - Mediana 9
  6 - Media aparada 15
  7 - Mediana 21
  8 - Mediana 41
  9 - Mediana 21 + EMA lenta

  O Arduino continua inalterado.
  A interpolacao afeta somente a garrafa.
*/

final int METODOS = 10;
final int HIST = 190;
final int JANELA = 41;

final int CICLO_ALVO_MS = 500;
final int DURACAO_ANIM_MS = 650;
final int PRAZO_SEM_ECO_MS = 2000;

final float SALTO_CONFIRMAR_CM = 2.5f;
final float TOLERANCIA_CONFIRMACAO_CM = 1.8f;
final float VARIACAO_VISUAL_MIN_CM = 0.25f;

// Novos parametros
final float ALFA_EMA_21 = 0.08f;
final int IDADE_MAX_MEDIANA_41_MS = 5500;

final String[] NOMES = {
  "Bruta",
  "Mediana 3",
  "Mediana 5",
  "Media movel 3",
  "Media movel 5",
  "Mediana 9",
  "Media aparada 15",
  "Mediana 21",
  "Mediana 41",
  "Mediana 21 + EMA"
};

int[] CORES = new int[METODOS];

boolean[] mostrar = {
  false, false, false, false, 
  false, true, false, true,
  true, true
};

// Preserva a mediana 21 + ema como referencia.
// Se existir configuracao salva, ela prevalece.
int fonte = 9;

// ====================================
// SERIAL
// ====================================

Serial serial;
String[] portas = {};

String portaAtual = "--";
String aviso = "Conecte o Arduino";

final ArrayDeque<String> fila =
  new ArrayDeque<String>();

// ====================================
// CALIBRACAO
// ====================================

float vazioCm = 16.0f;
float cheioCm = 4.5f;

boolean vazioRegistrado = false;
boolean cheioRegistrado = false;

final float distanciaMinimaFisica = 2.0f;
float distanciaMaximaFisica = 22.0f;

// ====================================
// PROCESSAMENTO
// ====================================

float[] valores = new float[METODOS];

float[] janela = new float[JANELA];
int[] temposJanela = new int[JANELA];

int janelaPos = 0;
int janelaN = 0;

float[][] historico =
  new float[METODOS][HIST];

int histPos = 0;
int histN = 0;

// Estado do novo filtro EMA
float ema21 = Float.NaN;

int ultimoPacoteValido = -100000;
int ultimaAvaliacao = 0;
int ultimaConfirmacao = -100000;

boolean ultimoPacoteFalhou = false;

String qualidade = "Aguardando amostras";

// ====================================
// DIAGNOSTICO CONSOLIDADO
// ====================================

final int DIAG_CAP = 180;

int[] diagTempo = new int[DIAG_CAP];
int[] diagTipo = new int[DIAG_CAP];

int diagPos = 0;
int diagN = 0;

long totalValidas = 0;
long totalSemEco = 0;
long totalForaFaixa = 0;
long totalFormato = 0;

float ultimaDistanciaSerial = Float.NaN;
String ultimaClassificacao = "SEM DADOS";

int ultimoResumo = -100000;

String resumoDiagnostico =
  "Aguardando dados do Arduino";

// ====================================
// REPRESENTACAO VISUAL
// ====================================

boolean possuiVisual = false;

float animDe = 0;
float animPara = 0;

int animInicio = 0;

float ultimoAlvo = Float.NaN;
float candidatoPendente = Float.NaN;

int tela = 0;
boolean temaEscuro = false;

// ====================================
// CORES
// ====================================

int cFundo, cPainel, cAtivo, cTexto;
int cSec, cBorda, cGrade, cAcento;

int cBotao, cBotaoHover, cBotaoTexto;
int cSucesso, cAviso;

int cVidro, cVidroBorda;
int cArroz, cArrozClaro;

Random gerador = new Random(947);

float[] graoX = new float[620];
float[] graoY = new float[620];
float[] graoAng = new float[620];

// ====================================
// SETUP
// ====================================

void setup() {
  size(1100, 740);

  surface.setTitle(
    "Silo de arroz | Monitoramento ultrassonico"
  );

  smooth(4);
  frameRate(30);

  textFont(createFont("SansSerif", 15));

  Arrays.fill(valores, Float.NaN);

  for (int i = 0; i < METODOS; i++) {
    Arrays.fill(historico[i], Float.NaN);
  }

  for (int i = 0; i < graoX.length; i++) {
    graoX[i] =
      119 + gerador.nextFloat() * 188;

    graoY[i] =
      177 + gerador.nextFloat() * 271;

    graoAng[i] =
      (gerador.nextFloat() - 0.5f) * 1.5f;
  }

  carregarConfiguracao();
  aplicarTema();
  atualizarPortas();

  for (String p : portas) {
    if (p.equalsIgnoreCase("COM3")) {
      conectar(p);
      break;
    }
  }
}

// ====================================
// TEMAS
// ====================================

void aplicarTema() {
  if (temaEscuro) {
    cFundo = color(22, 25, 23);
    cPainel = color(30, 34, 31);
    cAtivo = color(43, 53, 46);

    cTexto = color(235, 239, 235);
    cSec = color(157, 169, 160);
    cBorda = color(54, 64, 57);
    cGrade = color(53, 63, 56);

    cAcento = color(117, 194, 142);

    cBotao = color(43, 53, 46);
    cBotaoHover = color(55, 72, 60);
    cBotaoTexto = color(232, 239, 234);

    cSucesso = color(125, 207, 153);
    cAviso = color(229, 177, 105);

    cVidro = color(40, 47, 43);
    cVidroBorda = color(127, 149, 136);

    cArroz = color(146, 113, 74);
    cArrozClaro = color(225, 197, 151);

    CORES[0] = color(177, 186, 181);
    CORES[1] = color(112, 182, 193);
    CORES[2] = color(229, 174, 105);
    CORES[3] = color(170, 173, 222);
    CORES[4] = color(112, 209, 148);
    CORES[5] = color(240, 202, 129);
    CORES[6] = color(116, 181, 221);
    CORES[7] = color(211, 137, 186);
    CORES[8] = color(245, 135, 110);
    CORES[9] = color(116, 219, 206);

  } else {
    cFundo = color(245, 247, 244);
    cPainel = color(255);
    cAtivo = color(232, 242, 235);

    cTexto = color(35, 45, 40);
    cSec = color(106, 121, 111);
    cBorda = color(221, 228, 221);
    cGrade = color(231, 235, 230);

    cAcento = color(31, 111, 71);

    cBotao = color(238, 243, 238);
    cBotaoHover = color(222, 234, 225);
    cBotaoTexto = color(43, 83, 57);

    cSucesso = color(28, 135, 76);
    cAviso = color(177, 111, 35);

    cVidro = color(244, 248, 246);
    cVidroBorda = color(141, 159, 148);

    cArroz = color(184, 146, 96);
    cArrozClaro = color(247, 222, 175);

    CORES[0] = color(106, 118, 112);
    CORES[1] = color(35, 130, 162);
    CORES[2] = color(192, 118, 49);
    CORES[3] = color(122, 103, 170);
    CORES[4] = color(23, 130, 77);
    CORES[5] = color(169, 102, 36);
    CORES[6] = color(28, 117, 174);
    CORES[7] = color(155, 68, 126);
    CORES[8] = color(191, 86, 56);
    CORES[9] = color(0, 126, 128);
  }
}

// ====================================
// DRAW
// ====================================

void draw() {
  consumirFila();

  int agora = millis();

  if (
    agora - ultimaAvaliacao >= CICLO_ALVO_MS
  ) {
    ultimaAvaliacao = agora;
    avaliarNovoAlvo();
  }

  if (
    agora - ultimoResumo >= 1000
  ) {
    ultimoResumo = agora;
    atualizarResumo();
  }

  background(cFundo);

  cabecalho();

  if (tela == 0) {
    monitor();
  } else {
    ajustes();
  }

  stroke(cBorda);
  strokeWeight(1);

  line(27, 711, 1073, 711);

  noStroke();
  fill(cSec);

  textSize(12);
  textAlign(LEFT);

  text(
    "Arduino Uno  /  HC-SR04  /  115200 baud",
    29, 729
  );

  textAlign(RIGHT);

  text(
    "Percentual da faixa operacional, nao volume",
    1071, 729
  );

  textAlign(LEFT);
}

// ====================================
// DIAGNOSTICO
// ====================================

void registrarEvento(int tipo) {
  diagTempo[diagPos] = millis();
  diagTipo[diagPos] = tipo;

  diagPos =
    (diagPos + 1) % DIAG_CAP;

  diagN =
    min(diagN + 1, DIAG_CAP);
}

void atualizarResumo() {
  int[] contagens = new int[5];
  int agora = millis();

  for (int i = 0; i < diagN; i++) {
    int idx =
      (diagPos - 1 - i + DIAG_CAP)
      % DIAG_CAP;

    if (
      agora - diagTempo[idx] > 10000
    ) {
      continue;
    }

    int tipo = diagTipo[idx];

    if (tipo >= 0 && tipo < 5) {
      contagens[tipo]++;
    }
  }

  String distancia =
    Float.isNaN(ultimaDistanciaSerial)
      ? "--"
      : nf(ultimaDistanciaSerial, 0, 2) + " cm";

  resumoDiagnostico =
    "Sensor: " + distancia +
    " (" + ultimaClassificacao + ")" +
    "   |   10 s: " +
    contagens[0] + " OK, " +
    contagens[1] + " sem eco, " +
    (contagens[2] + contagens[3]) +
    " fora da faixa" +
    "   |   Alvo: " + qualidade;
}

// ====================================
// ESTADOS
// ====================================

String estadoLeitura() {
  if (serial == null) {
    return "DESCONECTADO";
  }

  if (!possuiVisual) {
    return "COLETANDO AMOSTRAS";
  }

  if (
    millis() - ultimoPacoteValido >
    PRAZO_SEM_ECO_MS
  ) {
    return "SEM LEITURA ATUAL";
  }

  if (
    ultimoPacoteFalhou ||
    millis() - ultimaConfirmacao > 1200
  ) {
    return "LEITURA MANTIDA";
  }

  return "MONITORANDO";
}

// ====================================
// CABECALHO
// ====================================

void cabecalho() {
  fill(cTexto);
  textAlign(LEFT);
  textSize(26);

  text("Silo de arroz", 29, 48);

  fill(cSec);
  textSize(13);

  text(
    "Monitoramento ultrassonico  /  Engenharia da Computacao - USF",
    30, 70
  );

  String estado = estadoLeitura();

  fill(
    estado.equals("MONITORANDO")
      ? cSucesso
      : cAviso
  );

  ellipse(784, 46, 8, 8);

  fill(cSec);
  textSize(11);

  text(estado, 796, 50);

  botao(
    915, 30, 78, 35,
    temaEscuro ? "CLARO" : "ESCURO"
  );

  botao(
    1000, 30, 74, 35,
    tela == 0 ? "AJUSTES" : "VOLTAR"
  );

  stroke(cBorda);
  line(27, 87, 1073, 87);

  noStroke();
}

// ====================================
// COMPONENTES VISUAIS
// ====================================

void moldura(
  float x, float y,
  float w, float h
) {
  fill(cPainel);
  stroke(cBorda);
  strokeWeight(1);

  rect(x, y, w, h, 6);

  noStroke();
}

void tituloSecao(
  String titulo,
  float x, float y
) {
  fill(cSec);
  textAlign(LEFT);
  textSize(13);

  text(titulo, x, y);
}

void botao(
  float x, float y,
  float w, float h,
  String titulo
) {
  fill(
    dentro(x, y, w, h)
      ? cBotaoHover
      : cBotao
  );

  stroke(cBorda);
  strokeWeight(1);

  rect(x, y, w, h, 4);

  noStroke();

  fill(cBotaoTexto);
  textAlign(CENTER, CENTER);
  textSize(12);

  text(
    titulo,
    x + w / 2,
    y + h / 2 - 1
  );

  textAlign(LEFT, BASELINE);
}

boolean dentro(
  float x, float y,
  float w, float h
) {
  return mouseX >= x &&
    mouseX <= x + w &&
    mouseY >= y &&
    mouseY <= y + h;
}

// ====================================
// INTERPOLACAO VISUAL
// ====================================

float distanciaVisual() {
  if (!possuiVisual) {
    return Float.NaN;
  }

  float t = constrain(
    (millis() - animInicio) /
    (float) DURACAO_ANIM_MS,
    0, 1
  );

  return lerp(animDe, animPara, t);
}

// ====================================
// NIVEL OPERACIONAL
// ====================================

float percentual(float cm) {
  return 100.0f *
    (vazioCm - cm) /
    (vazioCm - cheioCm);
}

String textoPercentual(float cm) {
  float n = percentual(cm);

  if (n < 0) return "<0%";
  if (n > 100) return ">100%";

  return nf(n, 0, 1) + "%";
}

String estadoOperacional(float cm) {
  float n = percentual(cm);

  if (n < 0) {
    return "ABAIXO DO MINIMO";
  }

  if (n > 100) {
    return "ACIMA DO MAXIMO";
  }

  if (n < 20) {
    return "ESTOQUE BAIXO";
  }

  if (n < 80) {
    return "OPERACAO NORMAL";
  }

  return "PROXIMO DO MAXIMO";
}

// ====================================
// MONITORAMENTO
// ====================================

void monitor() {
  moldura(26, 106, 365, 364);
  moldura(409, 106, 665, 154);
  moldura(409, 270, 665, 200);
  moldura(26, 484, 1048, 213);

  tituloSecao(
    "Reservatorio  /  5 litros (original)",
    48, 135
  );

  desenharGarrafa();

  tituloSecao(
    "Nivel operacional",
    434, 135
  );

  float d = distanciaVisual();

  fill(cTexto);
  textAlign(LEFT);
  textSize(60);

  text(
    possuiVisual
      ? textoPercentual(d)
      : "--%",
    436, 211
  );

  fill(possuiVisual ? cAcento : cSec);
  textSize(12);

  text(
    possuiVisual
      ? estadoOperacional(d)
      : "AGUARDANDO MEDICAO",
    438, 238
  );

  fill(cTexto);
  textSize(29);

  text(
    possuiVisual
      ? nf(d, 0, 2) + " cm"
      : "-- cm",
    805, 183
  );

  fill(cSec);
  textSize(12);

  text("DISTANCIA EXIBIDA", 807, 207);
  text("Fonte: " + NOMES[fonte], 807, 238);

  tituloSecao(
    "Comparacao dos metodos",
    434, 295
  );

  fill(cSec);
  textSize(11);

  text(
    "Quadrado: mostrar curva  |  Nome: usar na garrafa",
    435, 311
  );

  // 10 metodos no painel existente.
  for (int i = 0; i < METODOS; i++) {
    float y = 328 + i * 15.1f;

    if (i == fonte) {
      noStroke();
      fill(cAtivo);

      rect(
        422, y - 12,
        638, 15, 2
      );

      fill(cAcento);
      rect(422, y - 12, 3, 15);
    }

    stroke(CORES[i]);
    strokeWeight(1.3f);
    noFill();

    rect(438, y - 10, 11, 11, 2);

    if (mostrar[i]) {
      line(440, y - 5, 443, y - 2);
      line(443, y - 2, 449, y - 9);
    }

    noStroke();

    fill(i == fonte ? cTexto : cSec);
    textSize(11);
    textAlign(LEFT);

    text(NOMES[i], 469, y);

    textAlign(RIGHT);
    fill(cTexto);

    text(
      !Float.isNaN(valores[i]) &&
      millis() - ultimoPacoteValido < 1200
        ? nf(valores[i], 0, 2) + " cm"
        : "--",
      933, y
    );

    if (i == fonte) {
      fill(cAcento);
      ellipse(1031, y - 4, 8, 8);
    } else {
      noFill();
      stroke(cBorda);

      ellipse(1031, y - 4, 8, 8);
      noStroke();
    }

    textAlign(LEFT);
  }

  grafico();
}

// ====================================
// GARRAFA
// ====================================

float ladoE(float y) {
  return y <= 394
    ? 119
    : lerp(
        119, 190,
        constrain((y - 394) / 54.0f, 0, 1)
      );
}

float ladoD(float y) {
  return y <= 394
    ? 307
    : lerp(
        307, 236,
        constrain((y - 394) / 54.0f, 0, 1)
      );
}

void desenharGarrafa() {
  float cima = 177;
  float baixo = 448;

  float d = distanciaVisual();

  float p = possuiVisual
    ? constrain(percentual(d), 0, 100)
    : 0;

  float topo = lerp(
    baixo, cima + 6, p / 100.0f
  );

  fill(cVidro);
  stroke(cVidroBorda);
  strokeWeight(2);

  beginShape();

  vertex(119, cima);
  vertex(307, cima);
  vertex(307, 394);
  vertex(236, baixo);
  vertex(236, 458);
  vertex(190, 458);
  vertex(190, baixo);
  vertex(119, 394);

  endShape(CLOSE);
  noStroke();

  if (possuiVisual && p > 0) {
    fill(cArroz);

    beginShape();

    vertex(ladoE(topo) + 2, topo);
    vertex(ladoD(topo) - 2, topo);

    if (topo < 394) {
      vertex(305, 394);
    }

    vertex(234, baixo);
    vertex(192, baixo);

    if (topo < 394) {
      vertex(121, 394);
    }

    endShape(CLOSE);

    strokeWeight(1.5f);

    for (int i = 0; i < graoX.length; i++) {
      float x = graoX[i];
      float y = graoY[i];

      if (
        y >= topo + 2 &&
        y <= baixo - 3 &&
        x >= ladoE(y) + 5 &&
        x <= ladoD(y) - 5
      ) {
        stroke(
          i % 3 == 0
            ? cArrozClaro
            : lerpColor(
                cArroz, cArrozClaro, 0.55f
              )
        );

        float dx =
          3.2f * cos(graoAng[i]);

        float dy =
          3.2f * sin(graoAng[i]);

        line(
          x - dx, y - dy,
          x + dx, y + dy
        );
      }
    }

    stroke(cArrozClaro);

    line(
      ladoE(topo) + 2,
      topo,
      ladoD(topo) - 2,
      topo
    );
  }

  stroke(cVidroBorda, 65);
  strokeWeight(1);

  for (int y = 224; y < 390; y += 43) {
    line(124, y, 302, y);
  }

  noStroke();

  fill(cVidroBorda);
  rect(191, 458, 44, 8, 2);

  stroke(cVidroBorda);
  line(119, cima, 307, cima);

  noStroke();

  fill(cSec);
  textSize(11);
  textAlign(LEFT);

  text("100%", 319, 183);
  text("50%", 319, 313);
  text("0%", 319, 447);

  if (!possuiVisual) {
    textAlign(CENTER);

    text(
      "Aguardando amostras",
      213, 308
    );

    textAlign(LEFT);
  }
}

// ====================================
// GRAFICO COMPARATIVO
// ====================================

void grafico() {
  tituloSecao(
    "Historico comparativo",
    48, 507
  );

  fill(cSec);
  textSize(10);
  textAlign(LEFT);

  text(
    resumoDiagnostico,
    49, 530
  );

  textAlign(RIGHT);

  text(
    "Distancia (cm)",
    1054, 507
  );

  textAlign(LEFT);

  final float x1 = 90;
  final float x2 = 1046;

  final float y1 = 550;
  final float y2 = 658;

  float menor = Float.POSITIVE_INFINITY;
  float maior = Float.NEGATIVE_INFINITY;

  for (int i = 0; i < histN; i++) {
    int pos =
      (histPos - histN + i + HIST) % HIST;

    for (int m = 0; m < METODOS; m++) {
      float v = historico[m][pos];

      if (
        mostrar[m] &&
        !Float.isNaN(v)
      ) {
        menor = min(menor, v);
        maior = max(maior, v);
      }
    }
  }

  boolean temPontos =
    menor != Float.POSITIVE_INFINITY;

  if (!temPontos) {
    menor = cheioCm;
    maior = vazioCm;
  }

  float margem = max(
    1.5f,
    (maior - menor) * 0.18f
  );

  menor = max(0, menor - margem);
  maior += margem;

  if (maior - menor < 3) {
    maior = menor + 3;
  }

  stroke(cGrade);
  strokeWeight(1);

  fill(cSec);
  textSize(11);
  textAlign(RIGHT);

  for (int i = 0; i <= 3; i++) {
    float y = lerp(
      y1, y2,
      i / 3.0f
    );

    line(x1, y, x2, y);

    text(
      nf(
        lerp(maior, menor, i / 3.0f),
        0, 1
      ),
      x1 - 10,
      y + 4
    );
  }

  textAlign(LEFT);

  for (int m = 0; m < METODOS; m++) {
    if (!mostrar[m]) continue;

    stroke(CORES[m]);

    strokeWeight(
      m == fonte ? 2.5f : 1.5f
    );

    noFill();

    boolean aberto = false;

    for (int i = 0; i < histN; i++) {
      int pos =
        (histPos - histN + i + HIST) % HIST;

      float v = historico[m][pos];

      if (Float.isNaN(v)) {
        if (aberto) {
          endShape();
          aberto = false;
        }

        continue;
      }

      float x =
        x2 -
        (histN - 1 - i) *
        (x2 - x1) /
        (HIST - 1);

      float y = map(
        v,
        menor, maior,
        y2, y1
      );

      if (!aberto) {
        beginShape();
        aberto = true;
      }

      vertex(x, y);
    }

    if (aberto) {
      endShape();
    }
  }

  noStroke();

  fill(cSec);
  textSize(11);
  textAlign(RIGHT);

  text("agora", 1046, 679);

  if (!temPontos) {
    textAlign(CENTER);

    text(
      "Aguardando amostras",
      567, 605
    );
  }

  textAlign(LEFT);
}

// ====================================
// AJUSTES
// ====================================

void ajustes() {
  moldura(26, 106, 501, 590);
  moldura(544, 106, 530, 590);

  tituloSecao(
    "Conexao serial",
    49, 138
  );

  fill(cSec);
  textSize(13);

  text(
    "Porta: " + portaAtual +
    "  /  115200 baud",
    49, 167
  );

  botao(
    408, 122, 98, 32,
    "ATUALIZAR"
  );

  for (
    int i = 0;
    i < min(5, portas.length);
    i++
  ) {
    float y = 185 + i * 33;

    boolean atual =
      portas[i].equals(portaAtual);

    if (atual) {
      fill(cAtivo);
      rect(48, y, 455, 29, 3);
    }

    fill(atual ? cAcento : cTexto);
    textSize(13);

    text(
      (i + 1) + "   " +
      portas[i] +
      (atual ? "  (conectada)" : ""),
      61, y + 20
    );
  }

  stroke(cBorda);
  line(48, 364, 503, 364);
  noStroke();

  tituloSecao(
    "Calibracao da faixa operacional",
    49, 391
  );

  fill(cSec);
  textSize(12);

  text("Limite inferior (0%)", 62, 423);
  text("Limite superior (100%)", 289, 423);

  fill(cTexto);
  textSize(29);

  text(
    nf(vazioCm, 0, 2) + " cm",
    62, 461
  );

  text(
    nf(cheioCm, 0, 2) + " cm",
    289, 461
  );

  botao(
    60, 479, 200, 35,
    "REGISTRAR MINIMO"
  );

  botao(
    287, 479, 200, 35,
    "REGISTRAR MAXIMO"
  );

  botao(60, 527, 46, 30, "- 0,2");
  botao(112, 527, 46, 30, "+ 0,2");
  botao(287, 527, 46, 30, "- 0,2");
  botao(339, 527, 46, 30, "+ 0,2");

  fill(
    vazioRegistrado && cheioRegistrado
      ? cSucesso
      : cAviso
  );

  textSize(12);

  text(
    vazioRegistrado && cheioRegistrado
      ? "CALIBRACAO REGISTRADA"
      : "CALIBRACAO PROVISORIA",
    60, 587
  );

  stroke(cBorda);
  line(48, 605, 503, 605);
  noStroke();

  fill(cSec);
  textSize(12);

  text(
    "Maior distancia fisicamente aceitavel",
    60, 632
  );

  fill(cTexto);
  textSize(17);

  text(
    nf(distanciaMaximaFisica, 0, 1) + " cm",
    60, 661
  );

  botao(365, 637, 52, 30, "- 1");
  botao(425, 637, 52, 30, "+ 1");

  fill(cSec);
  textSize(11);

  text(aviso, 60, 685);

  tituloSecao(
    "Diagnostico",
    567, 138
  );

  fill(cSec);
  textSize(12);

  text("Estado", 568, 175);
  text("Amostras validas", 568, 207);
  text("Sem eco", 568, 239);
  text("Fora da faixa", 568, 271);

  fill(cTexto);
  textAlign(RIGHT);

  text(estadoLeitura(), 1049, 175);
  text("" + totalValidas, 1049, 207);
  text("" + totalSemEco, 1049, 239);
  text("" + totalForaFaixa, 1049, 271);

  textAlign(LEFT);

  stroke(cBorda);
  line(566, 299, 1051, 299);
  noStroke();

  tituloSecao(
    "Metodos / Ultima leitura",
    567, 325
  );

  String[] descricoes = {
    "Amostra direta",
    "Mediana de 3 amostras",
    "Mediana de 5 amostras",
    "Media de 3 amostras",
    "Media de 5 amostras",
    "Mediana de 9 amostras",
    "Media de 9 valores centrais entre 15",
    "Mediana de 21 amostras",
    "Mediana de 41 amostras",
    "Mediana 21 com suavizacao EMA lenta"
  };

  for (int i = 0; i < METODOS; i++) {
    int y = 345 + i * 32;

    fill(CORES[i]);
    rect(568, y - 11, 5, 25, 2);

    fill(cTexto);
    textSize(12);
    textAlign(LEFT);

    text(NOMES[i], 581, y);

    textAlign(RIGHT);

    text(
      !Float.isNaN(valores[i]) &&
      millis() - ultimoPacoteValido < 1200
        ? nf(valores[i], 0, 2) + " cm"
        : "--",
      1049, y
    );

    textAlign(LEFT);
    fill(cSec);
    textSize(10);

    text(descricoes[i], 581, y + 12);
  }

  fill(cSec);
  textSize(11);

  text(
    "Avaliacao: " + qualidade,
    568, 683
  );
}

// ====================================
// SERIAL
// ====================================

void serialEvent(Serial p) {
  if (p != serial) return;

  String linha = p.readStringUntil('\n');

  if (linha == null) return;

  synchronized(fila) {
    if (fila.size() >= 300) {
      fila.removeFirst();
    }

    fila.addLast(trim(linha));
  }
}

void consumirFila() {
  for (int n = 0; n < 160; n++) {
    String linha;

    synchronized(fila) {
      linha = fila.pollFirst();
    }

    if (linha == null) break;

    processar(linha);
  }
}

// ====================================
// PACOTES
// ====================================

void processar(String linha) {
  String[] p = split(linha, ',');

  if (p.length != 4) {
    totalFormato++;
    ultimaClassificacao = "FORMATO INVALIDO";
    ultimaDistanciaSerial = Float.NaN;

    registrarEvento(4);
    leituraInvalida();
    return;
  }

  if (p[0].equals("E")) {
    if (p[3].equals("SEM_ECO")) {
      totalSemEco++;
      ultimaClassificacao = "SEM ECO";

      registrarEvento(1);
    } else {
      totalFormato++;
      ultimaClassificacao = "PROTOCOLO INVALIDO";

      registrarEvento(4);
    }

    ultimaDistanciaSerial = Float.NaN;
    leituraInvalida();
    return;
  }

  if (!p[0].equals("D")) {
    totalFormato++;
    ultimaClassificacao = "TIPO INVALIDO";
    ultimaDistanciaSerial = Float.NaN;

    registrarEvento(4);
    leituraInvalida();
    return;
  }

  float cm = parseFloat(p[3]);

  if (
    Float.isNaN(cm) ||
    Float.isInfinite(cm)
  ) {
    totalFormato++;
    ultimaClassificacao = "NUMERO INVALIDO";
    ultimaDistanciaSerial = Float.NaN;

    registrarEvento(4);
    leituraInvalida();
    return;
  }

  ultimaDistanciaSerial = cm;

  if (cm < distanciaMinimaFisica) {
    totalForaFaixa++;
    ultimaClassificacao = "MUITO PROXIMO";

    registrarEvento(2);
    leituraInvalida();
    return;
  }

  if (cm > distanciaMaximaFisica) {
    totalForaFaixa++;
    ultimaClassificacao = "ACIMA DA FAIXA";

    registrarEvento(3);
    leituraInvalida();
    return;
  }

  ultimaClassificacao = "OK";
  registrarEvento(0);

  int agora = millis();

  // Reinicia a janela apenas apos
  // uma interrupcao prolongada.
  if (agora - ultimoPacoteValido > 900) {
    janelaPos = 0;
    janelaN = 0;
    candidatoPendente = Float.NaN;

    // O EMA nao deve misturar uma nova
    // sequencia com uma medicao muito antiga.
    ema21 = Float.NaN;
  }

  ultimoPacoteValido = agora;
  ultimoPacoteFalhou = false;
  totalValidas++;

  janela[janelaPos] = cm;
  temposJanela[janelaPos] = agora;

  janelaPos =
    (janelaPos + 1) % JANELA;

  janelaN =
    min(JANELA, janelaN + 1);

  calcularMetodos(agora);
  gravarHistorico();
}

void leituraInvalida() {
  ultimoPacoteFalhou = true;

  // Nao insere amostras invalidas
  // na janela estatistica.
  for (int i = 0; i < METODOS; i++) {
    historico[i][histPos] = Float.NaN;
  }

  avancarHistorico();
}

// ====================================
// ESTATISTICA
// ====================================

float[] ultimas(int n) {
  float[] a = new float[n];

  for (int i = 0; i < n; i++) {
    int idx =
      (janelaPos - 1 - i + JANELA)
      % JANELA;

    a[i] = janela[idx];
  }

  return a;
}

boolean janelaRecente(int n, int agora) {
  if (janelaN < n) return false;

  int indiceAntigo =
    (janelaPos - n + JANELA) % JANELA;

  return agora - temposJanela[indiceAntigo]
    <= n * 200;
}

// Verificacao extra apenas para a nova
// janela de 41 amostras.
boolean janela41Recente(int agora) {
  if (!janelaRecente(41, agora)) {
    return false;
  }

  int indiceAntigo =
    (janelaPos - 41 + JANELA) % JANELA;

  return agora - temposJanela[indiceAntigo]
    <= IDADE_MAX_MEDIANA_41_MS;
}

float mediana(int n) {
  float[] a = ultimas(n);

  Arrays.sort(a);
  return a[n / 2];
}

float media(int n) {
  float soma = 0;

  for (float v : ultimas(n)) {
    soma += v;
  }

  return soma / n;
}

float mediaAparada15() {
  float[] a = ultimas(15);

  Arrays.sort(a);

  float soma = 0;

  for (int i = 3; i < 12; i++) {
    soma += a[i];
  }

  return soma / 9.0f;
}

void calcularMetodos(int agora) {
  valores[0] = janelaN >= 1
    ? janela[(janelaPos - 1 + JANELA) % JANELA]
    : Float.NaN;

  valores[1] = janelaRecente(3, agora)
    ? mediana(3) : Float.NaN;

  valores[2] = janelaRecente(5, agora)
    ? mediana(5) : Float.NaN;

  valores[3] = janelaRecente(3, agora)
    ? media(3) : Float.NaN;

  valores[4] = janelaRecente(5, agora)
    ? media(5) : Float.NaN;

  valores[5] = janelaRecente(9, agora)
    ? mediana(9) : Float.NaN;

  valores[6] = janelaRecente(15, agora)
    ? mediaAparada15() : Float.NaN;

  valores[7] = janelaRecente(21, agora)
    ? mediana(21) : Float.NaN;

  // NOVO: mediana 41
  valores[8] = janela41Recente(agora)
    ? mediana(41) : Float.NaN;

  // NOVO: mediana 21 seguida de EMA.
  // Atualiza uma unica vez por nova
  // amostra valida, nao por frame.
  if (!Float.isNaN(valores[7])) {
    if (Float.isNaN(ema21)) {
      ema21 = valores[7];
    } else {
      ema21 += ALFA_EMA_21 *
        (valores[7] - ema21);
    }

    valores[9] = ema21;
  } else {
    valores[9] = Float.NaN;
  }
}

// ====================================
// HISTORICO
// ====================================

void gravarHistorico() {
  for (int i = 0; i < METODOS; i++) {
    historico[i][histPos] = valores[i];
  }

  avancarHistorico();
}

void avancarHistorico() {
  histPos = (histPos + 1) % HIST;
  histN = min(histN + 1, HIST);
}

// ====================================
// QUALIDADE DA JANELA
// ====================================

boolean janelaCoerente() {
  if (janelaN < 9) {
    return false;
  }

  float[] a = ultimas(9);

  float[] ordenados = a.clone();
  Arrays.sort(ordenados);

  float intervaloCentral =
    ordenados[6] - ordenados[2];

  if (intervaloCentral <= 2.8f) {
    return true;
  }

  int crescentes = 0;
  int decrescentes = 0;

  for (int i = 1; i < 9; i++) {
    float delta = a[i - 1] - a[i];

    if (delta > 0.18f) {
      crescentes++;
    } else if (delta < -0.18f) {
      decrescentes++;
    }
  }

  return max(crescentes, decrescentes) >= 6;
}

// ====================================
// AVALIACAO DO ALVO
// ====================================

void avaliarNovoAlvo() {
  int agora = millis();

  if (
    !janelaRecente(9, agora) ||
    agora - ultimoPacoteValido > 350
  ) {
    qualidade = "Aguardando janela";
    return;
  }

  if (!janelaCoerente()) {
    qualidade = "Janela instavel";
    candidatoPendente = Float.NaN;
    return;
  }

  float candidato = valores[fonte];

  if (Float.isNaN(candidato)) {
    qualidade = "Aguardando fonte";
    return;
  }

  if (!possuiVisual) {
    definirAlvo(candidato);
    qualidade = "Estimativa valida";
    return;
  }

  if (
    abs(candidato - ultimoAlvo) >
    SALTO_CONFIRMAR_CM
  ) {
    if (
      Float.isNaN(candidatoPendente) ||
      abs(candidato - candidatoPendente) >
      TOLERANCIA_CONFIRMACAO_CM
    ) {
      candidatoPendente = candidato;
      qualidade = "Confirmando mudanca";
      return;
    }
  }

  candidatoPendente = Float.NaN;

  ultimaConfirmacao = agora;
  qualidade = "Estimativa valida";

  if (
    abs(candidato - ultimoAlvo) >=
    VARIACAO_VISUAL_MIN_CM
  ) {
    definirAlvo(candidato);
  }
}

void definirAlvo(float cm) {
  float atual = possuiVisual
    ? distanciaVisual()
    : cm;

  possuiVisual = true;

  animDe = atual;
  animPara = cm;
  animInicio = millis();

  ultimoAlvo = cm;
  ultimaConfirmacao = millis();

  candidatoPendente = Float.NaN;
}

// ====================================
// CONEXAO SERIAL
// ====================================

void atualizarPortas() {
  portas = Serial.list();
  printArray(portas);
}

void conectar(String nome) {
  if (serial != null) {
    serial.stop();
    serial = null;
  }

  synchronized(fila) {
    fila.clear();
  }

  janelaN = 0;
  janelaPos = 0;

  Arrays.fill(valores, Float.NaN);

  for (int i = 0; i < METODOS; i++) {
    Arrays.fill(historico[i], Float.NaN);
  }

  histN = 0;
  histPos = 0;

  // Limpa estado do EMA ao reconectar.
  ema21 = Float.NaN;

  possuiVisual = false;
  ultimoAlvo = Float.NaN;
  candidatoPendente = Float.NaN;

  ultimoPacoteValido = -100000;
  ultimaConfirmacao = -100000;
  ultimoPacoteFalhou = false;

  qualidade = "Aguardando amostras";

  totalValidas = 0;
  totalSemEco = 0;
  totalForaFaixa = 0;
  totalFormato = 0;

  diagPos = 0;
  diagN = 0;

  ultimaDistanciaSerial = Float.NaN;
  ultimaClassificacao = "SEM DADOS";

  try {
    serial = new Serial(
      this, nome, 115200
    );

    serial.clear();
    serial.bufferUntil('\n');

    portaAtual = nome;
    aviso = "Porta aberta. Aguardando dados.";

  } catch (Exception e) {
    serial = null;
    portaAtual = "--";

    aviso =
      "Porta indisponivel. Feche o Monitor Serial.";

    println(e.getMessage());
  }
}

// ====================================
// MOUSE
// ====================================

void mousePressed() {
  if (dentro(915, 30, 78, 35)) {
    temaEscuro = !temaEscuro;

    aplicarTema();
    salvarConfiguracao();
    return;
  }

  if (dentro(1000, 30, 74, 35)) {
    tela = 1 - tela;
    return;
  }

  if (tela == 0) {
    for (int i = 0; i < METODOS; i++) {
      float y = 328 + i * 15.1f;

      if (dentro(433, y - 12, 28, 15)) {
        mostrar[i] = !mostrar[i];

        salvarConfiguracao();
        return;
      }

      if (dentro(464, y - 12, 593, 15)) {
        fonte = i;
        candidatoPendente = Float.NaN;

        salvarConfiguracao();
        return;
      }
    }

    return;
  }

  if (dentro(408, 122, 98, 32)) {
    atualizarPortas();
    return;
  }

  for (
    int i = 0;
    i < min(5, portas.length);
    i++
  ) {
    if (
      dentro(48, 185 + i * 33, 455, 29)
    ) {
      conectar(portas[i]);
      return;
    }
  }

  if (dentro(60, 479, 200, 35)) {
    calibrar(true);
    return;
  }

  if (dentro(287, 479, 200, 35)) {
    calibrar(false);
    return;
  }

  if (dentro(60, 527, 46, 30)) {
    ajustar(true, -0.2f);
    return;
  }

  if (dentro(112, 527, 46, 30)) {
    ajustar(true, 0.2f);
    return;
  }

  if (dentro(287, 527, 46, 30)) {
    ajustar(false, -0.2f);
    return;
  }

  if (dentro(339, 527, 46, 30)) {
    ajustar(false, 0.2f);
    return;
  }

  if (dentro(365, 637, 52, 30)) {
    ajustarMaximoFisico(-1);
    return;
  }

  if (dentro(425, 637, 52, 30)) {
    ajustarMaximoFisico(1);
    return;
  }
}

// ====================================
// TECLADO
// ====================================

void keyPressed() {
  if (key == 't' || key == 'T') {
    temaEscuro = !temaEscuro;

    aplicarTema();
    salvarConfiguracao();
    return;
  }

  if (key == 'a' || key == 'A') {
    tela = 1 - tela;
    return;
  }

  if (
    tela == 1 &&
    key >= '1' &&
    key <= '9'
  ) {
    int i = key - '1';

    if (i < portas.length) {
      conectar(portas[i]);
    }
  }
}

// ====================================
// CALIBRACAO
// ====================================

void calibrar(boolean inferior) {
  if (
    !janelaRecente(9, millis()) ||
    millis() - ultimoPacoteValido > 350 ||
    !janelaCoerente()
  ) {
    aviso =
      "Aguarde leituras estaveis para calibrar.";
    return;
  }

  float cm = mediana(9);

  if (inferior) {
    if (cm <= cheioCm + 2) {
      aviso =
        "Limite inferior deve ter maior distancia.";
      return;
    }

    vazioCm = cm;
    vazioRegistrado = true;

  } else {
    if (cm >= vazioCm - 2) {
      aviso =
        "Limite superior deve ter menor distancia.";
      return;
    }

    cheioCm = cm;
    cheioRegistrado = true;
  }

  salvarConfiguracao();

  aviso = inferior
    ? "Referencia inferior salva."
    : "Referencia superior salva.";
}

void ajustar(
  boolean inferior,
  float delta
) {
  float novo =
    (inferior ? vazioCm : cheioCm) + delta;

  if (
    novo < distanciaMinimaFisica ||
    novo > distanciaMaximaFisica ||
    (inferior && novo <= cheioCm + 2) ||
    (!inferior && novo >= vazioCm - 2)
  ) {
    aviso =
      "Valor fora da faixa aceitavel.";
    return;
  }

  if (inferior) {
    vazioCm = novo;
  } else {
    cheioCm = novo;
  }

  salvarConfiguracao();
  aviso = "Ajuste salvo.";
}

void ajustarMaximoFisico(float delta) {
  float novo =
    distanciaMaximaFisica + delta;

  if (
    novo < max(cheioCm + 2, vazioCm + 1) ||
    novo > 40
  ) {
    aviso =
      "Limite fisico fora da faixa.";
    return;
  }

  distanciaMaximaFisica = novo;

  salvarConfiguracao();
  aviso = "Limite de distancia salvo.";
}

// ====================================
// SALVAR CONFIGURACAO
// ====================================

void salvarConfiguracao() {
  JSONObject j = new JSONObject();

  j.setFloat("vazioCm", vazioCm);
  j.setFloat("cheioCm", cheioCm);

  j.setBoolean(
    "vazioRegistrado",
    vazioRegistrado
  );

  j.setBoolean(
    "cheioRegistrado",
    cheioRegistrado
  );

  j.setInt("fonte", fonte);
  j.setBoolean("temaEscuro", temaEscuro);

  j.setFloat(
    "distanciaMaximaFisica",
    distanciaMaximaFisica
  );

  for (int i = 0; i < METODOS; i++) {
    j.setBoolean(
      "mostrar" + i,
      mostrar[i]
    );
  }

  saveJSONObject(
    j,
    sketchPath("configuracao_silo.json")
  );
}

// ====================================
// CARREGAR CONFIGURACAO
// ====================================

void carregarConfiguracao() {
  File arquivo = new File(
    sketchPath("configuracao_silo.json")
  );

  if (!arquivo.exists()) return;

  try {
    JSONObject j =
      loadJSONObject(arquivo.getAbsolutePath());

    if (j.hasKey("distanciaMaximaFisica")) {
      float m =
        j.getFloat("distanciaMaximaFisica");

      if (m >= 8 && m <= 40) {
        distanciaMaximaFisica = m;
      }
    }

    float v = j.getFloat("vazioCm");
    float c = j.getFloat("cheioCm");

    if (
      v > c + 2 &&
      c >= distanciaMinimaFisica &&
      v <= distanciaMaximaFisica
    ) {
      vazioCm = v;
      cheioCm = c;

      if (j.hasKey("vazioRegistrado")) {
        vazioRegistrado =
          j.getBoolean("vazioRegistrado");
      }

      if (j.hasKey("cheioRegistrado")) {
        cheioRegistrado =
          j.getBoolean("cheioRegistrado");
      }
    }

    if (j.hasKey("fonte")) {
      fonte = constrain(
        j.getInt("fonte"),
        0, METODOS - 1
      );
    }

    if (j.hasKey("temaEscuro")) {
      temaEscuro =
        j.getBoolean("temaEscuro");
    }

    for (int i = 0; i < METODOS; i++) {
      if (j.hasKey("mostrar" + i)) {
        mostrar[i] =
          j.getBoolean("mostrar" + i);
      }
    }

  } catch (Exception e) {
    aviso =
      "Nao foi possivel carregar a configuracao.";
  }
}
