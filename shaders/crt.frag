// Filtro CRT de pantalla completa (docs/specs/settings.md § 3.2).
// Se usa con ImageFilter.shader (Impeller): el motor pone uSize (tamaño
// de la textura, px físicos) y uTexture (lo que hay debajo).
#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uScan;     // oscuridad de la scanline (0..1)
uniform float uMask;     // rejilla de apertura RGB (0..1)
uniform float uBloom;    // brillo de lo claro (0..1)
uniform float uVignette; // viñeta (0..1)
uniform float uCurve;    // curvatura de barril (k)
uniform float uLine;     // px físicos por scanline (>= 2)
uniform float uMaskW;    // px físicos por columna de la máscara
uniform sampler2D uTexture;

out vec4 fragColor;

vec3 glowAt(vec2 uv) {
  vec3 c = texture(uTexture, clamp(uv, 0.0, 1.0)).rgb;
  return max(c - 0.55, 0.0) / 0.45;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = frag / uSize;
  vec2 c = uv - 0.5;
  vec2 cuv = 0.5 + c * (1.0 + uCurve * dot(c, c));
  if (cuv.x < 0.0 || cuv.x > 1.0 || cuv.y < 0.0 || cuv.y > 1.0) {
    fragColor = vec4(0.0, 0.0, 0.0, 1.0);
    return;
  }
  vec4 base = texture(uTexture, cuv);
  vec3 col = base.rgb;

  // Bloom: lo claro de alrededor se suma suave (el píxel central no se
  // mezcla: el texto no se desenfoca).
  if (uBloom > 0.0) {
    vec2 px = 1.0 / uSize;
    vec3 g = glowAt(cuv + vec2(1.5, 0.0) * px) + glowAt(cuv - vec2(1.5, 0.0) * px)
        + glowAt(cuv + vec2(0.0, 1.5) * px) + glowAt(cuv - vec2(0.0, 1.5) * px)
        + glowAt(cuv + vec2(3.0, 3.0) * px) + glowAt(cuv - vec2(3.0, 3.0) * px)
        + glowAt(cuv + vec2(3.0, -3.0) * px) + glowAt(cuv - vec2(3.0, -3.0) * px);
    col += g * (uBloom * 0.125 * 0.6);
  }

  vec2 p = cuv * uSize;
  // Scanlines con forma de seno (una fila oscura cada uLine px).
  float s = 0.5 - 0.5 * cos(6.2831853 * p.y / uLine);
  col *= 1.0 - uScan * s;

  // Rejilla de apertura: columnas R / G / B.
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

  // Compensa el brillo que se comen scanlines y máscara.
  col *= 1.0 + uScan * 0.35 + uMask * 0.5;

  // Viñeta.
  float v = 1.0 - uVignette * smoothstep(0.08, 0.5, dot(c, c));
  col *= v;

  fragColor = vec4(min(col, vec3(base.a)), base.a);
}
