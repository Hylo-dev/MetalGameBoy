//
//  Shaders.metal
//  MetalGameBoy
//
//  Created by Eliomar Alejandro Rodriguez Ferrer on 31/12/25.
//

#include <metal_stdlib>
using namespace metal;

// Definiamo i dati in entrata: un semplice vettore da 4 float
// xy = Posizione dello schermo
// zw = Coordinate della texture
struct VertexIn {
    float4 posAndTex;
};

struct VertexOut {
    float4 position [[position]];
    float2 textureCoordinate;
};

vertex VertexOut basic_vertex(const device VertexIn* vertex_array [[buffer(0)]],
                              unsigned int vid [[vertex_id]]) {
    VertexOut out;
    
    // Leggiamo i 4 numeri tutti insieme
    float4 data = vertex_array[vid].posAndTex;
    
    // Costruiamo la posizione (aggiungiamo Z=0 e W=1 automaticamente)
    out.position = float4(data.x, data.y, 0.0, 1.0);
    
    // Estraiamo le coordinate texture (gli ultimi due numeri)
    out.textureCoordinate = float2(data.z, data.w);
    
    return out;
}

fragment float4 basic_fragment(VertexOut in [[stage_in]],
                               texture2d<float> texture [[texture(0)]]) {
    
    // Mag_filter: nearest serve per mantenere i pixel nitidi (effetto retro)
    constexpr sampler textureSampler(mag_filter::nearest, min_filter::nearest);
    
    return texture.sample(textureSampler, in.textureCoordinate);
}
