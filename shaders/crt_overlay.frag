// Filtro CRT sin Impeller (docs/specs/settings.md § 3.2): no puede leer
// la imagen, así que es un factor por píxel que se dibuja encima con
// BlendMode.multiply (scanlines + rejilla RGB + viñeta).
#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uScan;
uniform float uMask;
uniform float uBloom;    // sin uso aquí (mismo orden que crt.frag)
uniform float uVignette;
uniform float uCurve;    // sin uso aquí
uniform float uLine;
uniform float uMaskW;
uniform float uBezel;   // esquinas redondeadas (ver crt.frag)

out vec4 fragColor;

float bezelAt(vec2 p, vec2 size, float bezel) {
  if (bezel <= 0.0) return 1.0;
  float r = bezel * min(size.x, size.y);
  vec2 q = abs(p - size * 0.5) - (size * 0.5 - r);
  float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
  float edge = 1.0 - smoothstep(-1.5, 0.0, d);
  float shade = 1.0 - 0.3 * smoothstep(-r * 0.6, 0.0, d);
  return edge * shade;
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  vec2 c = p / uSize - 0.5;
  float s = 0.5 - 0.5 * cos(6.2831853 * p.y / uLine);
  vec3 col = vec3(1.0 - uScan * s);
  float m = mod(floor(p.x / uMaskW), 3.0);
  vec3 mask = vec3(1.0 - uMask);
  if (m < 0.5) {
    mask.r = 1.0;
  } else if (m < 1.5) {
    mask.g = 1.0;
  } else {
    mask.b = 1.0;
  }
  col *= mask;
  col *= 1.0 - uVignette * smoothstep(0.08, 0.5, dot(c, c));
  // Uso mínimo de los uniformes sin efecto (el compilador los quitaría
  // y cambiaría los índices).
  col *= bezelAt(p, uSize, uBezel);
  col *= 1.0 + 0.0 * (uBloom + uCurve);
  fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
