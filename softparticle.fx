
// 値を大きくすると境界面をより滑らかにする
// 小さいパーティクルに適用する場合には値を小さくすると良い
#define SOFTPARTICLE_SMOOTH_LENGTH 5

// カメラ位置変数宣言
float3 SPE_CameraPosition    : POSITION  < string Object = "Camera"; >;

//深度マップ保存テクスチャ
shared texture2D SPE_DepthTex : RENDERCOLORTARGET;
sampler2D SPE_DepthSamp = sampler_state {
    texture = <SPE_DepthTex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
//ソフトパーティクルエンジン使用フラグ
bool use_spe : CONTROLOBJECT < string name = "SoftParticleEngine.x"; >;

float getSrcDepth(float4 LastPos){
    float2 ScTex = LastPos.xyz/LastPos.w;
    ScTex.y *= -1;
    ScTex.xy += 1;
    ScTex.xy *= 0.5;
    return tex2D(SPE_DepthSamp,ScTex).r;
}

float getDepth( float3 WPos,
                float4 LastPos){
  if(use_spe){
    float srcDep = getSrcDepth(LastPos);
    float selfDep = length(SPE_CameraPosition - WPos);
    return smoothstep(0,SOFTPARTICLE_SMOOTH_LENGTH,(srcDep - selfDep));
  }
  return 1;
}

float getSoftParticleAlpha( float3 WPos,
                float4 LastPos){
  // ソフトパーティクルエンジンが読み込まれていれば処理をする
  if(use_spe)
  {
    // 深度
    float dep = length(SPE_CameraPosition - WPos);
    float scrdep = getSrcDepth(LastPos);

    dep = length(dep-scrdep);
    dep = smoothstep(0,SOFTPARTICLE_SMOOTH_LENGTH,dep);
    return dep;
  }
  return 1;
}

