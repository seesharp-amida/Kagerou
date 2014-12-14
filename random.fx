/* 
■エフェクト：
  乱数取得処理

■概要：
  擬似乱数を生成して取得する。
  単体で使用するものではなく、任意のエフェクトで下記のように記述して利用する。
  
  #include "./random.fx"
  
  使用にあたっては関数名その他の競合に注意の事。

■必須ファイル
  ・random256x256.bmp

■改造元ファイル：
  TexSnowLite.fx (そぼろ様)
*/

//乱数テクスチャ
texture2D RandomTexture <
    string ResourceName = "random256x256.bmp";
>;
sampler RandomTextureSampler = sampler_state {
    texture = <RandomTexture>;
    MINFILTER = NONE;
    MAGFILTER = NONE;
};

// 乱数テクスチャサイズ
#define RNDTEX_WIDTH  256
#define RNDTEX_HEIGHT 256

float2 calcTexturePos(float rindex){
  rindex *= 1021;
  float2 tpos = float2(rindex % RNDTEX_WIDTH, trunc(rindex / RNDTEX_WIDTH));
  tpos += float2(0.5,0.5);
  tpos /= float2(RNDTEX_WIDTH, RNDTEX_HEIGHT);
  return tpos;
}

//乱数取得
float4 getRandom4(float rindex)
{
    return tex2Dlod(RandomTextureSampler, float4(calcTexturePos(rindex),0,1));
}

//乱数取得
float getRandom(float rindex)
{
    return getRandom4(rindex).r;
}


