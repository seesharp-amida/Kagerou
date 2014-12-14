/*------------------------------------------------------------
■エフェクト名：
  Kagerou ver1.0

■作成者：
  SeeSharp
  http://www.nicovideo.jp/user/18593918
  
■概要：
  熱気を噴出させるポストエフェクト。もっと、熱くなれよぉおおおおおおおお！！！
  
  ※複数読み込むと重くなるのでコントロールオブジェクト指定を活用してみてください。
  ※そぼろ様のAutoLuminusと併用する場合、アクセサリ設定でALより「下」に配置して下さい。
  ※ビームマンP様のSoftParticleEngineとの併用必須(動作確認 v1.0)
  
  (ヽ´ω`)しょぼいエフェクトでごめんに…

■改造元/参考元ファイル：
  RealFireParticle (ビームマンP 様)
  SoftSmoke (ビームマンP 様)
  WaterParticle (ビームマンP 様)
  LineParticle (ビームマンP 様)
  AutoLuminous4 (そぼろ 様)
  
------------------------------------------------------------*/

// ↓↓↓↓↓↓↓↓↓↓パラメータ、ここから↓↓↓↓↓↓↓↓↓↓

// パーティクル数(上限 1000 )
#define PARTICLE_COUNT 400

// ◯時間の進み具合
//   ゆっくりにしたい場合は0.2など1以下の値にする。
float TimeRatio = 1.2;

// ◯上昇力
//   値を大きくすると熱気が昇っていきます
float UpdraftPower = 1;

// ◯噴出力
//   値を大きくするとより遠くまで噴出します
float JetPower = 32;

// ◯パーティクル回転
//   値を大きくするとより早く回ります。
float3 RotationSpeed = 62;

// ◯パーティクル基本サイズ
//   指定した値を基準にパーティクルサイズが計算されます。
float ScaleBase = 6;

// ◯パーティクルサイズ開始/終了
//   時間経過でScaleBeginからScaleEndへ各粒子の大きさが変わります。
//   ScaleBegin > ScaleEnd にしても動きます。
float ScaleBegin = 0.8;
float ScaleEnd = 1;

// ◯加算色
//   熱気に色を付けます。
float3 AddColor = {0.0, 0.0, 0.0};

// ◯歪み量
//   値を大きくするとよりぐにゃぐにゃ歪みます。
//   おすすめの値は 2 。
float DistPower = 2;

// ◯歪み固定距離。
//   カメラとの位置による歪み量減衰処理(この処理がないとカメラが離れるほど物体が大きく歪む)
//   の終点距離。この距離以降は歪み量は固定。
float FixDistLength = 500;

// ◯エミッター大きさ
//   開始点の大きさを指定します。
float3 EmitterScale = float3(1,1,1);

// ◯パーティクルの広がり角度
float ParticleSpread = 0;

// エミッター形状。使用したいもの以外をコメントアウト
#define EMITTER_SHAPE_SPHERE // 球状のエミッタ
//#define EMITTER_SHAPE_CUBE // 箱状のエミッタ

// 噴出方向（コントロールオブジェクトを指定しない場合のみ有効）
float3 JetDirection = float3( 0.0, 1.0, 0.0 );

// コントロールオブジェクト使用フラグ
// 使用するコントロールオブジェクトの数。使用しない場合は行ごとコメントアウト
#define CONTROLOBJECT_COUNT 1

#ifdef CONTROLOBJECT_COUNT

// コントロールオブジェクト指定
// ex) float4x4 emitter1 : CONTROLOBJECT < string name = "ファイル名"; string item = "ボーン名";>;
float4x4 emitter1 : CONTROLOBJECT < string name = "ダミーボーン.pmx"; string item = "ボーン01";>;

static float4x4 Emitters[CONTROLOBJECT_COUNT] = {
  emitter1,
};

#endif

// 歪みオン/オフ (デバッグ用) 1でオン/0でオフ
#define DIST_ACTIVE 1


// ↑↑↑↑↑↑↑↑↑↑パラメータ、ここまで↑↑↑↑↑↑↑↑↑↑


// パーティクル数の上限（Xファイルと連動しているので、変更不可）
#define PARTICLE_MAX_COUNT  1000

#ifndef CONTROLOBJECT_COUNT
#define TEX_HEIGHT  PARTICLE_COUNT
#else
#define TEX_HEIGHT  (PARTICLE_COUNT*2)
#endif

#define PI 3.14159265359  

#define OUT_OF_AREA float4((float3)100000, 0)

float4x4 WorldMatrix : World;
float4x4 ViewProjMatrix : ViewProjection;
static float scaling = length(WorldMatrix[0]);

float3 CameraPosition    : POSITION  < string Object = "Camera"; >;
float3 Rxyz : CONTROLOBJECT < string name = "(self)";string item = "Rxyz";>;
float Tr : CONTROLOBJECT < string name = "(self)";string item = "Tr";>;

float4x4 ViewMatrixInverse : VIEWINVERSE;

float time_0_X : Time;

// 乱数処理
#include "./random/mme.fx"
// ソフトパーティクルエンジン対応
#include "./softparticle.fx"
// ユーティリティ
#include "./util/mme.fx"

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float ViewportAspect = ViewportSize.x / ViewportSize.y;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);
static float2 OnePx = (float2(1,1)/ViewportSize);

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;


// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = "A8R8G8B8" ;
>;
sampler2D ScnSamp = sampler_state {
    texture = <ScnMap>;
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = None;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
texture DepthBuffer : RenderDepthStencilTarget <
    float2 ViewPortRatio = {1.0,1.0};
>;
//歪みテクスチャ
texture2D DistortionTexture <
    string ResourceName = "distortion.tga";
>;
sampler DistortionTextureSampler = sampler_state {
    texture = <DistortionTexture>;
    AddressU  = WRAP;
    AddressV = WRAP;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};


texture ParticleBaseTex : RenderColorTarget
<
   int Width=1;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
texture ParticleBaseTex2 : RenderColorTarget
<
   int Width=1;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
texture ParticleBaseDepthBuffer : RenderDepthStencilTarget <
   int Width=1;
   int Height=TEX_HEIGHT;
    string Format = "D24S8";
>;
sampler ParticleBase = sampler_state
{
   Texture = (ParticleBaseTex);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = NONE;
   MINFILTER = NONE;
   MIPFILTER = NONE;
};
sampler ParticleBase2 = sampler_state
{
   Texture = (ParticleBaseTex2);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = NONE;
   MINFILTER = NONE;
   MIPFILTER = NONE;
};
struct VS_OUTPUT {
   float4 Pos: POSITION;
   float2 texCoord: TEXCOORD0;
   float Distance: TEXCOORD1;
   float Age: TEXCOORD2;
   float3 WPos: TEXCOORD3;
   float4 LastPos: TEXCOORD4;
   float Index: TEXCOORD5;
};

float getTime(float idx){
  return frac(idx/float(PARTICLE_COUNT)*1278 + time_0_X*TimeRatio);
}

float3 getJetDir(int idx, float3 BasePos, float t){
  #ifdef CONTROLOBJECT_COUNT
    float2 dir_tex_coord = float2( 0.5, float(idx)/TEX_HEIGHT+ 0.5 + 0.5/TEX_HEIGHT);
    float3 jetOut = normalize(tex2Dlod(ParticleBase2, float4(dir_tex_coord,0,1)).xyz);
  #else
    float3 jetOut = normalize(JetDirection);
  #endif
  float spreadX = 2 * PI * ParticleSpread / 360.0 * (0.5 - getRandom(idx * 903 + BasePos.x * 1208));
  float spreadY = 2 * PI * ParticleSpread / 360.0 * (0.5 - getRandom(idx * 173 + BasePos.y * 1208));
  float spreadZ = 2 * PI * ParticleSpread / 360.0 * (0.5 - getRandom(idx * 349 + BasePos.z * 1208));
  
  jetOut = mul( jetOut, getRotY(Rxyz.y + spreadY) );
  jetOut = mul( jetOut, getRotX(Rxyz.x + spreadX) );
  jetOut = mul( jetOut, getRotZ(Rxyz.z + spreadZ) );
  return jetOut*JetPower*t;
}

float3 getBasePosition(int idx){
  float2 base_tex_coord = float2( 0.5, float(idx)/TEX_HEIGHT + 0.5/TEX_HEIGHT);
  return tex2Dlod(ParticleBase2, float4(base_tex_coord,0,1)).xyz;
}

VS_OUTPUT FireParticleSystem_Vertex_Shader_main(float4 Pos: POSITION){
  VS_OUTPUT Out = (VS_OUTPUT)0;
  Out.texCoord = (Pos.xy*0.5+0.5);
  
  int idx = floor(Pos.z*PARTICLE_MAX_COUNT);
  Out.Index = idx;
  
  if ( idx >= PARTICLE_COUNT ){
    Out.Pos = OUT_OF_AREA;
    return Out;
  }
  
  float t = getTime(idx);
  
  // スケール
  float sbegin = ScaleBase * ScaleBegin;
  float send = ScaleBase * ScaleEnd;
  Pos *= sbegin + (send - sbegin) * t;
  
  // 回転
  float rotation = PI * 2 * (RotationSpeed / 360.0 * t + getRandom(idx * 146) );
  Pos = mul( Pos.xyz, getRotZ(rotation) );
  Pos = mul( Pos.xyz, ViewMatrixInverse );
  
  float3 BasePos = getBasePosition(idx);
  
  Pos.xyz += BasePos;
  
  float3 JetDir = getJetDir(idx, BasePos, t);
  Pos.xyz += JetDir;
  
  Pos.y += UpdraftPower * pow(t,2);
  
  Out.Pos = mul(float4(Pos.xyz, 1), ViewProjMatrix);

  float distance = length(Pos.xyz - CameraPosition.xyz);
  float idxnum =1;
  float flength = pow(FixDistLength,idxnum);
  Out.Distance = (flength - clamp(pow(distance,idxnum),0,flength*0.9)) / flength;

  Out.Age = t;
  
  Out.LastPos = Out.Pos;
	Out.WPos = Pos.xyz;
  
  return Out;
}

float particleShape
<
   string UIName = "particleShape";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 1.00;
> = float( 0.37 );
texture Particle_Tex
<
   string ResourceName = "Particle.tga";
>;
sampler Particle = sampler_state
{
   Texture = (Particle_Tex);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = LINEAR;
   MINFILTER = LINEAR;
   MIPFILTER = LINEAR;
};

float4 calcDistortionColor(float Index, float4 DistPos, float DistPow, float Time){
  float t = Time * 0.1;
  float2 UVPos;
  UVPos.x = (DistPos.x / DistPos.w)*0.5+0.5;
  UVPos.y = (-DistPos.y / DistPos.w)*0.5+0.5;
  float4 dist = tex2D(DistortionTextureSampler,UVPos.xy + t + Index / PARTICLE_COUNT) * DistPow * 0.01;
  float4 color = tex2D(ScnSamp,UVPos.xy + dist.rb);
  return color;
}

float4 FireParticleSystem_Pixel_Shader_main(
  float2 TexCoord: TEXCOORD0,
  float Distance: TEXCOORD1,
  float Age: TEXCOORD2,
  float3 WPos: TEXCOORD3,
  float4 LastPos: TEXCOORD4,
  float Index: TEXCOORD5) : COLOR {
  
  if ( Index >= PARTICLE_COUNT ) return float4(0,0,0,0);
  float4 col = tex2D(Particle,TexCoord);
  
  // 透明度曲線
  // -90*((x-0.83)^24)-x^2+1
  col.a = col.r * (-90*pow(Age-0.83,24)-pow(Age,2)+1);
  
  col.a *= getDepth(WPos, LastPos);
  
  col.a *= Tr;
  
#if DIST_ACTIVE
  float4 dist = calcDistortionColor(Index, LastPos, DistPower * col.a * Distance, time_0_X);
  col.rgb = dist.rgb;
#endif
  col.rgb += AddColor;

  return col;
}

struct VS_OUTPUT2 {
   float4 Pos: POSITION;
   float2 texCoord: TEXCOORD0;
};

VS_OUTPUT2 ParticleBase_Vertex_Shader_main(float4 Pos: POSITION, float2 Tex: TEXCOORD) {
   VS_OUTPUT2 Out;
  
   Out.Pos = Pos;
   Out.texCoord = Tex;
   return Out;
}


float3 getEmitterPos(float idx){  
  // ランダムシード
  float seed1 = idx*193 + time_0_X;
  float seed2 = idx*2197 + time_0_X;
  float seed3 = idx*391 + time_0_X;
  
  #ifdef EMITTER_SHAPE_SPHERE
  float len = sin(seed1);
  float3 epos = float3(0,0,len);
  epos = mul(mul(epos,getRotX(2 * PI * sin(seed2))), getRotY(2 * PI * sin(seed3)));
  #endif
  
  #ifdef EMITTER_SHAPE_CUBE
  float3 epos = (float3)0;
  epos.x = sin(seed1);
  epos.y = sin(seed2);
  epos.z = sin(seed3);
  epos -= 0.5;
  #endif
  
  epos *= EmitterScale;
  epos = mul( epos, getRotY(Rxyz.y) );
  epos = mul( epos, getRotX(Rxyz.x) );
  epos = mul( epos, getRotZ(Rxyz.z) );
  
  return epos;
}

float4 ParticleBase_Pixel_Shader_main(float2 texCoord: TEXCOORD0) : COLOR {
  int idx = round(texCoord.y*TEX_HEIGHT);
  if ( idx >= PARTICLE_COUNT ) idx -= PARTICLE_COUNT;
  
  float t = getTime(idx);
  texCoord += float2(0.5, 0.5/TEX_HEIGHT);
  
  float4 old_color = tex2D(ParticleBase2, texCoord);
  
  if(time_0_X == 0){
    return OUT_OF_AREA;
  }else{
    if ( old_color.a <= t ) {
      old_color.a = t;
      return old_color;
    } else {
      #ifdef CONTROLOBJECT_COUNT
        int eid = idx % CONTROLOBJECT_COUNT;
        if(texCoord.y < 0.5){
        
          if(Tr == 0){
            return float4(OUT_OF_AREA.xyz, t);
          }
          // 位置を保存
          float3 pos = mul(getEmitterPos(idx), Emitters[eid]) + Emitters[eid]._41_42_43;
          return float4(pos, t);
        }else{
          // 方向を保存
          float4x4 m = Emitters[eid];
          m._14_24_34 = 0;
          m._41_42_43 = 0;
          m._44 = 1;
          float4 rot = normalize(mul(float4(0,1,0,1), m));
          return float4(rot.xyz, t);
        }
      #else
        float3 pos = mul(getEmitterPos(idx), WorldMatrix) + WorldMatrix._41_42_43;
        return float4(pos, t);
      #endif
    }
  }
}

VS_OUTPUT2 ParticleBase2_Vertex_Shader_main(float4 Pos: POSITION, float2 Tex: TEXCOORD) {
   VS_OUTPUT2 Out;
  
   Out.Pos = Pos;
   Out.texCoord = Tex + float2(0.5, 0.5/TEX_HEIGHT);
   return Out;
}

float4 ParticleBase2_Pixel_Shader_main(float2 texCoord: TEXCOORD0) : COLOR {
   return tex2D(ParticleBase, texCoord);
}

VS_OUTPUT2 DrawOriginal_VS(float4 Pos: POSITION, float2 Tex: TEXCOORD) {
  VS_OUTPUT2 Out;

  Out.Pos = Pos;
  Out.texCoord = Tex + ViewportOffset;
  return Out;
}

float4 DrawOriginal_PS(float2 texCoord: TEXCOORD0) : COLOR {
   return tex2D(ScnSamp, texCoord);
}
float4 ClearColor = {0,0,0,1};
float ClearDepth  = 1.0;


//--------------------------------------------------------------//
// Technique Section for Effect Workspace.Particle Effects.FireParticleSystem
//--------------------------------------------------------------//
technique FireParticleSystem <
    string Script = 
      
      "RenderColorTarget0=ScnMap;"
      "RenderDepthStencilTarget=DepthBuffer;"
      "ClearSetColor=ClearColor; ClearSetDepth=ClearDepth;"
      "Clear=Color; Clear=Depth;"
      "ScriptExternal=Color;"
      
      "RenderColorTarget0=;"
      "RenderDepthStencilTarget=;"
      "ClearSetColor=ClearColor; ClearSetDepth=ClearDepth;"
      "Clear=Depth;"
      "Clear=Color;"
      "Pass=DrawOriginal;"
      
      "Pass=ParticleSystem;"
    ;
> {
  pass ParticleBase < string Script = "Draw=Buffer;";>
  {
      ALPHABLENDENABLE = FALSE;
      ALPHATESTENABLE=FALSE;
      VertexShader = compile vs_3_0 ParticleBase_Vertex_Shader_main();
      PixelShader = compile ps_3_0 ParticleBase_Pixel_Shader_main();
   }
  pass ParticleBase2 < string Script = "Draw=Buffer;";>
  {
      ALPHABLENDENABLE = FALSE;
      ALPHATESTENABLE=FALSE;
      VertexShader = compile vs_3_0 ParticleBase2_Vertex_Shader_main();
      PixelShader = compile ps_3_0 ParticleBase2_Pixel_Shader_main();
   }
   pass ParticleSystem
   {
      ZENABLE = TRUE;
      ZWRITEENABLE = FALSE;
      CULLMODE = NONE;
      VertexShader = compile vs_3_0 FireParticleSystem_Vertex_Shader_main();
      PixelShader = compile ps_3_0 FireParticleSystem_Pixel_Shader_main();
   }
   
   pass DrawOriginal< string Script= "Draw=Buffer;"; >
   {
      AlphaBlendEnable = false;
      VertexShader = compile vs_3_0 DrawOriginal_VS();
      PixelShader = compile ps_3_0 DrawOriginal_PS();
   }
}

