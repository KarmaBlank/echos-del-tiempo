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

out vec4 fragColor;

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
  col *= 1.0 + 0.0 * (uBloom + uCurve);
  fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
