# Silo Inteligente — Monitoramento de Nível de Arroz

Protótipo acadêmico desenvolvido por estudantes de **Engenharia da Computação da Universidade São Francisco (USF)**, campus Bragança Paulista, em 2026.

O projeto utiliza um **Arduino UNO**, um **sensor ultrassônico HC-SR04** e uma interface em **Processing 4** para acompanhar o nível de arroz em um reservatório experimental. O sistema permite observar o enchimento e o esvaziamento, visualizar a distância até a superfície do material e comparar métodos de filtragem das medições.

> **Importante:** o percentual exibido representa o nível na **faixa operacional calibrada**, não a porcentagem exata da massa ou do volume de arroz armazenado.

## Objetivo

Demonstrar a integração entre eletrônica, instrumentação, programação e processamento de dados por meio da medição ultrassônica sem contato direto com o material armazenado.

## Componentes

- Arduino UNO R3 ou compatível;
- Sensor ultrassônico HC-SR04;
- Protoboard, cabos jumper e cabo USB;
- Garrafa PET transparente de capacidade original de 5 L, cortada e invertida;
- Registro de esfera de PVC e conexões para a descarga;
- Estrutura de sustentação e arroz para demonstração;
- Notebook com Arduino IDE e Processing 4.

### Ligações elétricas

| HC-SR04 | Arduino UNO |
| --- | --- |
| VCC | 5 V |
| GND | GND |
| TRIG | D9 |
| ECHO | D10 |

O Arduino recebe alimentação e se comunica com o notebook pelo cabo USB.

## Estrutura do protótipo

O recipiente é uma garrafa PET cortada, transparente e invertida. A abertura superior permite o posicionamento do HC-SR04, apontado aproximadamente para o centro da superfície do arroz. Um registro de esfera de PVC instalado na saída inferior permite controlar manualmente a vazão.

As medidas aproximadas do recipiente utilizado são **15 cm de largura interna**, **15,5 cm de altura até o início da rosca** e **10 cm de região com paredes quase retas**. A geometria da montagem pode influenciar os ecos ultrassônicos.

## Funcionamento

1. O HC-SR04 emite um pulso ultrassônico e recebe o eco refletido pela superfície do arroz.
2. O Arduino mede o tempo do pulso de retorno e calcula a distância em centímetros.
3. A distância é transmitida ao notebook pela comunicação serial USB (**115200 baud**), com aquisição aproximadamente a cada **90 ms**.
4. O Processing avalia a plausibilidade das distâncias, identifica falhas de leitura e aplica os métodos estatísticos.
5. O painel apresenta a distância estimada, o nível operacional e um histórico gráfico, com representação visual gradual do arroz.

### Protocolo serial

Medição de distância obtida:

```text
D,sequencia,millis,distancia_cm
```

Ausência de pulso completo dentro do tempo limite:

```text
E,sequencia,millis,SEM_ECO
```

O Arduino transmite a distância quando recebe um pulso completo; cabe ao Processing decidir se ela está dentro da faixa física configurada.

## Processamento das medições

Durante o desenvolvimento, foram comparados **dez métodos**:

1. Leitura bruta;
2. Mediana de 3 amostras;
3. Mediana de 5 amostras;
4. Média móvel de 3 amostras;
5. Média móvel de 5 amostras;
6. Mediana de 9 amostras;
7. Média aparada de 15 amostras;
8. Mediana de 21 amostras;
9. Mediana de 41 amostras;
10. **Mediana de 21 amostras + EMA lenta**.

### Método selecionado: Mediana 21 + EMA lenta

O método adotado combina duas etapas:

1. **Mediana de 21:** seleciona o valor central das últimas 21 amostras válidas e recentes, reduzindo a influência de picos isolados.
2. **Média móvel exponencial (EMA):** suaviza a saída da mediana com coeficiente **α = 0,08**, atualizado a cada nova amostra válida.

A atualização exponencial segue a expressão:

```text
EMA_atual = EMA_anterior + 0,08 × (Mediana21_atual − EMA_anterior)
```

Nos testes práticos do protótipo, essa combinação apresentou **maior estabilidade visual** do que os demais métodos comparados, especialmente em relação à leitura bruta. O ganho de estabilidade introduz atraso na resposta; isso foi aceito por ser adequado à demonstração do nível do silo.

O Processing também consolida periodicamente estimativas e utiliza **interpolação linear apenas na representação visual**, sem inventar medições intermediárias no histórico dos métodos.

> Filtragem não equivale a validação metrológica: ecos incorretos persistentes ainda podem afetar a estimativa.

## Calibração e nível operacional

A interface utiliza duas referências configuráveis:

- **0% operacional:** maior distância de referência, correspondente ao limite inferior monitorado;
- **100% operacional:** menor distância de referência, correspondente ao limite superior monitorado.

A conversão é:

```text
Nível (%) = [(D_0% − D_atual) / (D_0% − D_100%)] × 100
```

Quando a estimativa ultrapassa as referências, o painel pode indicar **abaixo do mínimo** ou **acima do máximo**. O valor não representa diretamente o volume nem a massa dos grãos, especialmente porque o recipiente possui uma região afunilada.

O Processing permite ajustar as referências e os limites físicos das leituras. As configurações locais são salvas em `configuracao_silo.json`.

## Interface do Processing

- Representação visual do recipiente e do arroz;
- Nível operacional e distância estimada;
- Gráfico comparativo dos métodos;
- Seleção do método que controla a representação;
- Diagnóstico resumido de amostras aceitas, leituras sem eco e fora da faixa;
- Configuração de calibração e porta serial;
- Temas claro e escuro;
- Preservação temporária da última estimativa em caso de falhas de leitura.

## Organização do repositório

```text
silo-inteligente-arduino/
├── arduino/
│   └── MonitorSiloArduino/
│       └── MonitorSiloArduino.ino
├── processing/
│   └── MonitorSiloArroz/
│       └── MonitorSiloArroz.pde
└── README.md
```

## Como executar

### Arduino

1. Conecte o HC-SR04 conforme a tabela de ligações.
2. Abra `arduino/MonitorSiloArduino/MonitorSiloArduino.ino` no **Arduino IDE**.
3. Selecione a placa **Arduino UNO** e a porta correspondente.
4. Compile e envie o programa ao Arduino.

### Processing

1. Instale o **Processing 4** e a biblioteca **Serial**, se ainda não estiver disponível.
2. Abra `processing/MonitorSiloArroz/MonitorSiloArroz.pde`.
3. Feche o **Monitor Serial do Arduino IDE**, pois a porta não pode ser utilizada pelos dois programas simultaneamente.
4. Execute o sketch do Processing.
5. O programa tenta se conectar automaticamente à **COM3** se ela estiver disponível; caso contrário, selecione a porta em **Ajustes**.
6. Configure as referências do nível operacional conforme a montagem.
7. Selecione **Mediana 21 + EMA** como fonte da garrafa. Para defini-la como padrão em uma instalação sem configuração salva, use `int fonte = 9;` no sketch.

O arquivo `configuracao_silo.json` é gerado localmente para guardar preferências e medidas específicas da montagem. **Não é necessário versioná-lo no GitHub.**

## Resultados observados

Foi demonstrada a comunicação Arduino–Processing, a aquisição de distâncias pelo HC-SR04 e a atualização da interface. Os testes práticos mostraram oscilações nas leituras, inclusive durante a descarga do arroz, o que motivou a comparação entre métodos estatísticos.

A **Mediana 21 + EMA lenta** apresentou o comportamento mais estável observado pela equipe e foi escolhida como padrão. A descarga pode ser controlada manualmente pela abertura parcial do registro inferior.

Esses resultados são **qualitativos**. Não foi realizada uma validação quantitativa da precisão absoluta da medição.

## Limitações e melhorias futuras

- A superfície irregular do arroz e a formação de depressões durante a descarga podem alterar os ecos.
- Reflexões nas paredes ou na região afunilada podem produzir leituras incorretas.
- A suavização adiciona atraso e não elimina necessariamente ecos falsos persistentes.
- O sistema mede nível operacional estimado, não massa ou volume exatos.

Possíveis evoluções incluem registro permanente dos dados, comunicação sem fio, alertas remotos, automação da descarga, sensores ambientais e calibração volumétrica específica do recipiente.

## Equipe

Projeto acadêmico de **Engenharia da Computação — Universidade São Francisco (USF), Bragança Paulista, 2026**.

| Integrante | Responsabilidade |
| --- | --- |
| João Pedro Cezar | Programação do Arduino e do Processing |
| João Pedro Dutra Ermiliato | Estrutura física e montagem |
| Tiago Alves de Souza | Documentação técnica |
| Samuel Batista Lambert | Desenvolvimento do site |

## Site do projeto

A documentação acadêmica, a fundamentação teórica, a montagem e os resultados estão disponíveis no **[Google Sites — Projeto Silo Inteligente](https://sites.google.com/mail.usf.edu.br/projeto-materiais-eletricos/p%C3%A1gina-inicial)**.

---

*Projeto desenvolvido para fins acadêmicos e demonstrativos.*
