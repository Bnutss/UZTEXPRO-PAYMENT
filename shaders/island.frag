// Metaballs: the Dynamic Island (a rounded rectangle) and the avatar (a
// circle) as two fields that add up; where the sum passes the threshold the
// pixel is inked, so the two shapes flow into each other. The avatar photo is
// sampled inside the circle and blurred as it nears the island.
#include <flutter/runtime_effect.glsl>

// Ball 1: the island. Center, half size, corner radius.
uniform vec2 uCenter1;
uniform vec2 uHalfSize1;
uniform float uCornerR1;
// Ball 2: the avatar. Center and nominal radius; the drawn radius shrinks
// toward the island's as the two get close.
uniform vec2 uCenter2;
uniform float uRadius2;
uniform float uThreshold;
uniform vec2 uImageSize;
// 1 while the app is on screen; 0 when the system takes its snapshot, which
// has no island in it, so the drawn one must not show.
uniform float uIslandOn;
// Half size of the area the real island covers. Nothing is drawn inside it:
// the cut-out is black already, and a pill drawn there would be seen next to
// it whenever the screen slides (a swipe between apps).
uniform vec2 uCutHalf;

uniform sampler2D uImage;

out vec4 fragColor;

const int SAMPLES = 56;
// Golden angle spreads the samples evenly over a Fibonacci spiral.
const float GOLDEN_ANGLE = 2.39996;
const float MAX_BLUR = 20.0;
// How far from the island, in avatar radii, the avatar starts to shrink.
const float REACH = 2.5;

// Gaussian blur from samples on a Fibonacci spiral. pixToUv turns a radius in
// pixels into a step in texture coordinates.
vec4 sampleBlurred(vec2 uv, vec2 pixToUv, float radius) {
  if (radius < 0.5) return texture(uImage, uv);

  vec4 sum = vec4(0.0);
  float total = 0.0;
  float sigma = radius * 0.4;

  for (int i = 0; i < SAMPLES; i++) {
    float r = sqrt(float(i) / float(SAMPLES)) * radius;
    float theta = float(i) * GOLDEN_ANGLE;
    vec2 offset = vec2(cos(theta), sin(theta)) * r * pixToUv;
    float w = exp(-0.5 * r * r / (sigma * sigma));
    sum += texture(uImage, clamp(uv + offset, 0.0, 1.0)) * w;
    total += w;
  }
  return sum / total;
}

void main() {
  vec2 pos = FlutterFragCoord().xy;

  // Nothing above the island: that is the status bar's.
  float topEdge = uCenter1.y - uHalfSize1.y + 6.0;
  if (pos.y < topEdge) {
    fragColor = vec4(0.0);
    return;
  }

  // Distance from the avatar's center to the island's surface (the signed
  // distance to a rounded rectangle).
  vec2 qDist = abs(uCenter2 - uCenter1) - (uHalfSize1 - uCornerR1);
  float surfDist =
      length(max(qDist, 0.0)) + min(max(qDist.x, qDist.y), 0.0) - uCornerR1;

  // The closer to the island, the smaller the avatar: the merge looks right
  // when both balls are about the same size.
  float proximity = smoothstep(0.0, uRadius2 * REACH, surfDist);
  float actualR2 = mix(uHalfSize1.y, uRadius2, proximity);

  // Field of the island: r^2 / d^2 on the same distance. The epsilon keeps
  // the division finite.
  vec2 q = abs(pos - uCenter1) - (uHalfSize1 - uCornerR1);
  float d1 = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
  float f1 = (uCornerR1 * uCornerR1) / (d1 * d1 + 0.0001);

  // Field of the avatar.
  vec2 d2 = pos - uCenter2;
  float f2 = (actualR2 * actualR2) / (dot(d2, d2) + 0.0001);

  float field = f1 + f2;
  float edge = 0.01;
  float alpha = smoothstep(uThreshold - edge, uThreshold + edge, field);

  // The visible edge is where the field equals the threshold, at
  // R / sqrt(threshold); the photo is fitted to that, not to the raw radius.
  float effectiveR = actualR2 / sqrt(uThreshold);
  vec2 localPos = (pos - uCenter2) / effectiveR;

  // Fit the photo in the circle without stretching it.
  float imgAspect = uImageSize.x / uImageSize.y;
  vec2 uv;
  vec2 pixToUv;
  if (imgAspect > 1.0) {
    uv = vec2(localPos.x / imgAspect * 0.5 + 0.5, localPos.y * 0.5 + 0.5);
    pixToUv = vec2(0.5 / (effectiveR * imgAspect), 0.5 / effectiveR);
  } else {
    uv = vec2(localPos.x * 0.5 + 0.5, localPos.y * imgAspect * 0.5 + 0.5);
    pixToUv = vec2(0.5 / effectiveR, 0.5 * imgAspect / effectiveR);
  }
  // Explicit, so the result does not depend on the sampler's wrap mode.
  uv = clamp(uv, 0.0, 1.0);

  // The nearer the island, the blurrier and darker the photo.
  float blurProximity =
      1.0 - smoothstep(0.0, uRadius2 / sqrt(uThreshold), surfDist);
  vec4 photo = sampleBlurred(uv, pixToUv, MAX_BLUR * blurProximity);
  photo.rgb *= 1.0 - 0.45 * blurProximity;

  // Image where the circle dominates, black where the island does.
  float t = smoothstep(0.35, 0.65, f2 / (f1 + f2 + 0.00001));
  vec4 withIsland = mix(vec4(0.0, 0.0, 0.0, 1.0), photo, t) * alpha;

  // Without the island (the system's snapshot has none) the field is still
  // worked out the same way, so the avatar keeps exactly the size it has with
  // the island; only the island's own pixels are left out.
  vec4 avatarOnly = vec4(photo.rgb, 1.0) * alpha * t;

  vec4 drawn = mix(avatarOnly, withIsland, uIslandOn);

  // Leave the real island's own area empty; the neck and the avatar start at
  // its edge.
  vec2 cut = abs(pos - uCenter1) - (uCutHalf - uCutHalf.y);
  float cutDist = length(max(cut, 0.0)) + min(max(cut.x, cut.y), 0.0) - uCutHalf.y;
  fragColor = drawn * smoothstep(0.0, 1.0, cutDist);
}
