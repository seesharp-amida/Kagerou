/* 
■エフェクト：
  ユティリティー関数定義

■概要：
  よく使う便利関数を定義する。
  単体で使用するものではなく、任意のエフェクトで下記のように記述して利用する。
  
  #include "./util.fx"
  
  使用にあたっては関数名その他の競合に注意の事。
*/

float4x4 getRotX(float r){
  float4x4 matRot = (float4x4)0;
   matRot[0] = float4(1,0,0,0); 
   matRot[1] = float4(0,cos(r),sin(r),0); 
   matRot[2] = float4(0,-sin(r),cos(r),0); 
   matRot[3] = float4(0,0,0,1);
   return matRot;
}

float4x4 getRotY(float r){
  float4x4 matRot = (float4x4)0;
   matRot[0] = float4(cos(r),0,-sin(r),0); 
   matRot[1] = float4(0,1,0,0); 
   matRot[2] = float4(sin(r),0,cos(r),0); 
   matRot[3] = float4(0,0,0,1); 
   return matRot;
}

float4x4 getRotZ(float r){
  float4x4 matRot = (float4x4)0;
   matRot[0] = float4(cos(r),sin(r),0,0); 
   matRot[1] = float4(-sin(r),cos(r),0,0); 
   matRot[2] = float4(0,0,1,0); 
   matRot[3] = float4(0,0,0,1); 
   return matRot;
}

float getLookAt(float3 Eye, float3 At, float3 Up){
  float3 zaxis = normalize(Eye - At);
  float3 xaxis = normalize(cross(Up, zaxis));
  float3 yaxis = cross(zaxis, xaxis);
  
  float4x4 mat = (float4x4)0;
  mat[0] = float4( xaxis.x,           yaxis.x,           zaxis.x,          0);
  mat[1] = float4( xaxis.y,           yaxis.y,           zaxis.y,          0);
  mat[2] = float4( xaxis.z,           yaxis.z,           zaxis.z,          0);
  mat[3] = float4( -dot(xaxis, Eye),  -dot(yaxis, Eye),  -dot(zaxis, Eye), 1);
  
  return mat;
}