﻿#ifndef UBER_STANDARD_CORE_INCLUDED
#define UBER_STANDARD_CORE_INCLUDED

#include "UnityCG.cginc"
#include "UnityShaderVariables.cginc"
#include "UnityInstancing.cginc"
#include "../UBER_StandardConfig.cginc"
#include "UnityLightingCommon.cginc"
#include "UnityPBSLighting.cginc"
#include "UnityStandardUtils.cginc"
#include "UnityMetaPass.cginc"
#include "UnityStandardBRDF.cginc"
#include "UnityGBuffer.cginc"

#include "../Includes/UBER_StandardInput.cginc"
#include "../Includes/UBER_StandardUtils2.cginc"

//#include "AutoLight.cginc"
// replace AutoLight.cginc LIGHT_ATTENUATION() macros to get independent control over shadows
#include "../Includes/UBER_AutoLightMOD.cginc"

/* _Paint3DAccumulator_ */
struct appdata_P3DA
{
	float4 vertex : POSITION;
	#ifdef _CUSTOM_VERTEX_DISPLACEMENT_
	float3 normal : NORMAL;
	#endif
	float2 uv : TEXCOORD0;
};

struct v2f_P3DA
{
	float4 vertex : SV_POSITION;
	float2 uv0 : TEXCOORD0;
	float2 uv1 : TEXCOORD0;

	#ifdef UNITY_REQUIRE_FRAG_WORLDPOS
	float3 worldPos : TEXCOORD1;
	#ifdef _CUSTOM_VERTEX_DISPLACEMENT_
	float3 normal : TEXCOORD2;
	#endif
	#endif
	
	#if !defined(UNITY_REQUIRE_FRAG_WORLDPOS) && defined(_CUSTOM_VERTEX_DISPLACEMENT_)
	float3 normal : TEXCOORD1;
	#endif
};


struct ControllerData
{
	//float3 position;
	half3 brushMode;//.x: 0 = normal, 1 = blend between 2 textures
	//float3 targetPos;
	//float3 normal;
	//float3 paintingParams;//0 or 1 or -10 if inactve
	half3 color;

};

int2 _RT_Resolution;

float4 _Color_P3DA;
float4 _EraserColor_P3DA;
sampler2D _MainTex_P3DA;
float4 _MainTex_P3DA_ST;
float _HeightMapStrength_P3DA;

#ifdef _BLEND_2_TEXTURES_WITH_PAINT_
sampler2D _OverlayTex_Before_P3DA;
float4 _OverlayTex_Before_P3DA_ST;
sampler2D _OverlayTex_After_P3DA;
#endif


//sampler2D _MainTexInternal_P3DA;

/// Contains the accumulated paint data
uniform RWTexture2D<float4> _MainTexInternal_P3DA : register(u3);
//uniform Texture2D<float4> _MainTexScreen_P3DA_Reader;// : register(u2);	
//uniform sampler2D _MainTexScreen_P3DA_Reader;// : register(u2);	
//float4 _MainTexInternal_P3DA_ST;
//sampler2D _MainTexInternal_P3DA_Sampler;

//sampler2D _MainTexScreen_P3DA;
//SamplerState samplerInput;
/// Contains the accumulated paint data + everything not painted on, like color picker, tooltips etc.
uniform RWTexture2D<float4> _MainTexScreen_P3DA : register(u2);
//float4 _MainTexScreen_P3DA_ST;

#ifdef _CUSTOM_VERTEX_DISPLACEMENT_
	uniform RWTexture2D<float4> _DisplacementTexInternal_P3DA : register(u4);
	//#define _WPosNegativeRangeOffset 1000
	//#define _VertexDispScale 0.2
#endif

sampler2D _BgTex_P3DA;
float4 _BgTex_P3DA_ST;

float _BrushScaleMod_P3DA;
float _BrushScaleOffset_P3DA;
//float _DistanceFadeOffset;
//float _DistanceFadeScale;
float4 _PlayParams_P3DA;
//float4 _BrushPosWS[2];
//float4 _BrushNormal[2];
//float4 _ControllerScale;
//float4 _ControllerOffset;
static const int BRUSH_COUNT_P3DA = 2;
//StructuredBuffer<ControllerData> _BrushBuffer_P3DA;
uniform RWStructuredBuffer<ControllerData> _BrushBuffer_P3DA : register(u1);
uniform float4 _PositionWS_P3DA[BRUSH_COUNT_P3DA];
uniform float4 _PositionSS_P3DA[BRUSH_COUNT_P3DA];
uniform float4 _PaintingParams_P3DA[BRUSH_COUNT_P3DA];
uniform float4x4 _Matrix_iTR_P3DA[BRUSH_COUNT_P3DA];
float _Init_P3DA;

int _UVsToUse_P3DA;
float4 _Atlas_ST_PerMaterial_P3DA;

float4 _ConeShapeXY_P3DA;
//float _SprayCentreHardness;
float _ConeScale_P3DA;
float _ConeScale2_P3DA;
float _ConeScalePow_P3DA;
float _ConeClamp_P3DA;

float4 _FadeShapeXY_P3DA;
float _FadeScalePow_P3DA;
float4 _FadeScale_P3DA;

float _BlendSubtraction_P3DA;
float _BlendAddition_P3DA;

float _TargetRingLocation_P3DA;
float _TargetRingThickness_P3DA;

float _SprayBlend_P3DA;
float _EraseBlend_P3DA;

#ifdef _GPU_COLOR_PICKER_
	float _ColorSampleThresh_P3DA;

	//<only used by passes with color picker>
	sampler2D _ColorPicker_P3DA;
	float4 _ColorPicker_P3DA_ST;
	float _ColorSampleDist_P3DA;
	float4 _ColorSampleDist_P3DA_ST;

	sampler2D _ColorPickerDisplay_P3DA;
	//float4 _ColorPickerDisplay_P3DA_ST;
#endif

sampler2D _ToolOutlineTex_P3DA;
float4 _ToolOutlineTex_P3DA_ST;

float4 _ColorSamplerVolume_P3DA;
//</only used by passes with color picker>


struct FragmentOutput
{
	float4 color : SV_Target0;
	float4 colorInternal : SV_Target1;

};

float sdCylinder(float3 p, float3 c)
{
	return length(p.xz - c.xy) - c.z;
}

float sdCone(float3 p, float2 c, float zStop)// iq
{
	// c must be normalized
	float q = length(p.xy);
	if (p.z > zStop)
		return dot(c, float2(q, p.z));
	else return 0;
}

//cone section
float sdCone2(float3 p, float r1, float h)//, float r2)
{
	float d1 = -p.y - h;
	float q = p.y - h;
	//float si = 0.5*(r1 - r2) / h;
	float si = 0.5*(r1) / h;
	//float d2 = max(sqrt(dot(p.xz, p.xz)*(1.0 - si*si)) + q*si - r2, q);
	float d2 = max(sqrt(dot(p.xz, p.xz)*(1.0 - si*si)) + q*si, q);
	return length(max(float2(d1, d2), 0.0)) + min(max(d1, d2), 0.);
}

// Cone with correct distances to tip and base circle. Y is up, 0 is in the middle of the base.
float sdCone3(float3 p, float radius, float height)
{
	float2 q = float2(length(p.xz), p.y);
	float2 tip = q - float2(0, height);
	float2 mantleDir = normalize(float2(height, radius));
	float mantle = dot(tip, mantleDir);
	float d = max(mantle, -q.y);
	float projected = dot(tip, float2(mantleDir.y, -mantleDir.x));

	// distance to tip
	if ((q.y > height) && (projected < 0)) {
		d = max(d, length(tip));
	}

	// distance to base ring
	if ((q.x > radius) && (projected > length(float2(height, radius)))) {
		d = max(d, length(q - float2(radius, 0)));
	}
	return d;
}

float sdSphere(float3 p, float s)
{
	return length(p) - s;
}

float2 opU(float d1, float d2)
{
	return (d1<d2) ? d1 : d2;
}

float opI(float d1, float d2)
{
	return max(d1, d2);
}

float map(float s, float a1, float a2, float b1, float b2)
{
	return b1 + (s - a1)*(b2 - b1) / (a2 - a1);
}

// power smooth min (k = 8);
float2 smin(float2 a, float2 b, float k)
{

	a.x = pow(a.x, k);
	b.x = pow(b.x, k);
	float2 res;

	res.x = pow((a.x*b.x) / (a.x + b.x), 1.0 / k);


	res.y = (a.x < b.x) ? a.y : b.y;


	return res;
}

// power smooth min (k = 8);
float smax(float a, float b, float k)
{
	return a.x + b.x - pow(a.x*a.x + b.x*b.x, -k); // http://www.hyperfun.org/HOMA08/48890118.pdf


}


float2 opBlendSmin(float2 d1, float2 d2, float k)
{
	return smin(d1, d2, k);
}

float opBlendSmax(float d1, float d2, float k)
{
	return smax(d1, d2, k);
}

float3 opRotateTranslate(float4 p, float4x4 m)
{
	//float3 q = invert(m)*p;
	float3 q = mul(m,p).xyz;
	return q;
}

//subtraction
float opS(float d1, float d2)
{
	return max(-d1, d2);
}

/* _Paint3DAccumulator_ */

float4 _ReadVertexDataFromRT(float2 inuv){
	float4 textureVals = float4(0,0,0,0);
	#ifdef _CUSTOM_VERTEX_DISPLACEMENT_
	float2 uv = inuv;//*_Atlas_ST_PerMaterial_P3DA.xy + _Atlas_ST_PerMaterial_P3DA.zw;
	//float4 textureVals = tex2Dlod(_MainTexInternal_P3DA_Sampler, float4(uv, 0.0, 0.0));
	int coordx = int((uv.x)*_RT_Resolution.x);
	int coordy = int((uv.y)*_RT_Resolution.y);
	int2 mainUVRWT = int2(coordx,coordy);
	textureVals = _DisplacementTexInternal_P3DA[mainUVRWT];
	#endif
	return textureVals;
}

void GetBrushSDFBase(int i, float2 dims, float3 pos, out float sphereDFv, out float coneDFv){
		//pos = opRotateTranslate(float4(pos.x, pos.y, pos.z, 1), _Matrix_iTR[i]).xyz;
		//pos = pos - _PositionWS_P3DA[i];
		pos = pos - _PositionWS_P3DA[i];
		//float3 toolToPixelDirWS = normalize(pos);

		pos = opRotateTranslate(float4(pos.x, pos.y, pos.z, 1), _Matrix_iTR_P3DA[i]).xyz;// - _PositionWS_P3DA[i].xyz;

		pos.z += _ConeShapeXY_P3DA.z;
		float fadeDist = pos.z * _ConeShapeXY_P3DA.w - pos.z;

		coneDFv = sdCone(pos / _ConeScale_P3DA, dims / _ConeScale_P3DA, _ConeClamp_P3DA)*_ConeScale_P3DA*_ConeScale2_P3DA;
		coneDFv = pow(coneDFv, _ConeScalePow_P3DA);


		float3 spherePos = pos;
		spherePos.z += _FadeShapeXY_P3DA.w;
		spherePos *= _FadeScale_P3DA;
		sphereDFv = sdSphere(spherePos / _FadeShapeXY_P3DA.x, _FadeShapeXY_P3DA.z / _ConeScale_P3DA)*_FadeShapeXY_P3DA.x*_FadeShapeXY_P3DA.y;
		//return sphereDFv;
}

float GetBrushSDFForPainting(float i, float2 dims, float3 pos){
		float sphereDFv;
		float coneDFv;
		GetBrushSDFBase(i, dims, pos, sphereDFv, coneDFv);
		sphereDFv = pow(sphereDFv, _FadeScalePow_P3DA);

		//float blend = opBlendSmin(coneDFv, sphereDFv, _FadeScale_P3DA.w);
		float blend = opBlendSmax(coneDFv, sphereDFv, _BlendSubtraction_P3DA);
		return blend;
}

void GetBrushSDFToolShell(int i, float2 dims, float3 pos, out float2 blend, out float cylinderDFv){
	  float sphereDFv;
	  float coneDFv;
		GetBrushSDFBase(i, dims, pos, sphereDFv, coneDFv);
		//sphereDFv = pow(sphereDFv, _FadeScalePow_P3DA);

		float3 cylinderPos = float3(pos.x, pos.z, pos.y);
		cylinderDFv = sdCylinder( cylinderPos, _ColorSamplerVolume_P3DA.xyz)*_ColorSamplerVolume_P3DA.w;

		//float blend = opBlendSmin(coneDFv, sphereDFv, _FadeScale_P3DA.w);
		blend = float2(opBlendSmax(coneDFv, sphereDFv, _BlendSubtraction_P3DA), i);

		blend = opS(blend - _TargetRingLocation_P3DA, blend);
		blend = (blend*blend* _TargetRingThickness_P3DA);

    //float2 outdf = float2(1,1);
    //float2 outdf = float2(1,0);
		//outdf = opBlendSmin(outdf, blend, _BlendAddition_P3DA);// opI(coneDFv, sphereDFv);

		blend.x = 1 - max(blend.x, 0.1);
		blend.x = saturate(blend.x);
		//return blend;
}

v2f_P3DA Paint3DAccumulatorVertexLogic_P0(appdata_P3DA v, out float vertexHeight){
	v2f_P3DA o;

	#ifdef _CUSTOM_VERTEX_DISPLACEMENT_
	float2 uv = v.uv*_Atlas_ST_PerMaterial_P3DA.xy + _Atlas_ST_PerMaterial_P3DA.zw;
	//float4 textureVals = tex2Dlod(_MainTexInternal_P3DA_Sampler, float4(uv, 0.0, 0.0));
	int coordx = int((uv.x)*_RT_Resolution.x);
	int coordy = int((uv.y)*_RT_Resolution.y);
	int2 mainUVRWT = int2(coordx,coordy);
	float4 textureVals = _DisplacementTexInternal_P3DA[mainUVRWT];
	float height = (textureVals.x + textureVals.y + textureVals.z) / 3;
	vertexHeight = height;
	float3 normal = v.normal;
	if(textureVals.a < 1.0)
		normal = -normal;
	v.vertex.xyz += normal * height;
	o.normal =  mul(unity_ObjectToWorld, v.normal).xyz;
	#endif


	//o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
	// Tranforms position from object to homogenous space https://forum.unity3d.com/threads/unityobjecttoclippos.400520/
	//o.vertex = UnityObjectToClipPos(v.vertex);
	//o.uv = TRANSFORM_TEX(v.uv, _MainTexInternal_P3DA);
	//o.uv = TRANSFORM_TEX(v.uv, _MainTex_);
	#ifdef UNITY_REQUIRE_FRAG_WORLDPOS
	o.worldPos = float3(0,0,0);
	#endif
	o.vertex = float4(0,0,0,0);
	o.uv0 = float2(0,0);
	o.uv1 = float2(0,0);
	
	
	return o;
}

/* _Paint3DAccumulator_ */

float4 Paint3DAccumulatorFragmentLogic_P0(v2f_P3DA i){
	#ifdef _CUSTOM_VERTEX_DISPLACEMENT_
	float3 normalws = i.normal;		
	#endif
	//float4 prevColor = tex2D(_MainTexInternal_P3DA, i.uv*_MainTexInternal_P3DA_ST.xy + _MainTexInternal_P3DA_ST.zw);
	//float2 mainUV = i.uv0;//*_MainTexInternal_P3DA_ST.xy + _MainTexInternal_P3DA_ST.zw;
	float2 mainUVForRT = _UVsToUse_P3DA == 0 ? i.uv0 : i.uv1;
	#ifdef _BLEND_2_TEXTURES_WITH_PAINT_
		float2 mainUV = mainUVForRT*_OverlayTex_Before_P3DA_ST.xy + _OverlayTex_Before_P3DA_ST.zw;
	#endif
	mainUVForRT = mainUVForRT*_Atlas_ST_PerMaterial_P3DA.xy + _Atlas_ST_PerMaterial_P3DA.zw;
//mainUVForRT = mainUVForRT/_MainTex_ST.xy - _MainTex_ST.zw;
	int coordx = int((mainUVForRT.x)*_RT_Resolution.x);
	int coordy = int((mainUVForRT.y)*_RT_Resolution.y);
	int2 mainUVRWT = int2(coordx,coordy);
	
	float4 prevColor = _MainTexInternal_P3DA[mainUVRWT];
	//float4 prevScreenColor = _MainTexScreen_P3DA[mainUVRWT];
	#ifdef _CUSTOM_VERTEX_DISPLACEMENT_
		float4 displacementCol = _DisplacementTexInternal_P3DA[mainUVRWT];
		int displacedTF = 0;
	#endif

	float3 temprgb = prevColor.rgb;
	float2 uv2 = i.uv0*_BgTex_P3DA_ST.xy + _BgTex_P3DA_ST.zw;
	//float4 outColor = float4(0, 0, 0, 1);
	float4 outColor = tex2D(_BgTex_P3DA, uv2);
	outColor.a = prevColor.a;
	//float r_g_b_max = max(outColor.r,max(outColor.g,outColor.b));


	#if defined(UNITY_REQUIRE_FRAG_WORLDPOS) || defined(_CUSTOM_VERTEX_DISPLACEMENT_)
	float3 pxPosWorld = (i.worldPos.xyz);
	#else
	float3 pxPosWorld = float3(1,0,1);// this shader branch should not be reached
	#endif

	//float4 output = tex2D(_MainTex_P3DA, i.uv*_MainTex_P3DA_ST.xy + _MainTex_P3DA_ST.zw);
	//output.b = 1;
	//output.r = 1;

	//float2 outdf = float2(1,1);

	for (int i = 0; i < BRUSH_COUNT_P3DA; i++)
	{
		
		float3 pos = pxPosWorld;

		float2 dims = _ConeShapeXY_P3DA.xy;

		float blend = GetBrushSDFForPainting(i, dims, pos);



		//outdf = opBlendSmin(float2(outdf.x,1), float2(blend,2), _BlendAddition_P3DA);// opI(coneDFv, sphereDFv);
		//outdf.x = 1 - max(outdf.x, 0.1);
		//outdf.x = saturate(blend.x);

		blend.x = 1 - max(blend.x, 0.1);
		blend.x = saturate(blend.x);
		


		//float a = blend.x;
		//temprgb.xyz = _BrushBuffer_P3DA[i].color.xyz * a + temprgb.rgb * (1 - a);

		if (_PaintingParams_P3DA[i].y > 0)
		{
			// erase (paint black)
			blend.x /= _EraseBlend_P3DA;
			float a = saturate(blend.x);
			
			if(a>0.0000001)
			{
				//temprgb.xyz = _EraserColor_P3DA.rgb * a + temprgb.rgb * (1.0 - a);
				//float oneMinusA = 1-a;
				outColor.a += a;//oneMinusA;
				//outColor.a = 1-a;

				//And also erase the alpha on the displacement texture
				#ifdef _CUSTOM_VERTEX_DISPLACEMENT_
					displacedTF = 1;
					displacementCol.a -= a;//oneMinusA;
				#endif
			}
			
			
		}
		else
		if (_PaintingParams_P3DA[i].x > 0)
		{
			/*
			//_BrushBuffer_P3DA[i].color = _Color_P3DA;
			//float a = outdf.x;
			blend.x /= _SprayBlend_P3DA;
			float a = saturate(blend.x);
			temprgb.xyz = _BrushBuffer_P3DA[i].color.xyz * a + temprgb.rgb * (1.0 - a);
			//temprgb.xyz = _Color_P3DA * a + temprgb.rgb * (1.0 - a);
			*/

			blend.x /= _SprayBlend_P3DA;
			float a = saturate(blend.x);
			
			if(a>0.0000001)
			{
				//float alphaFlag = outColor.a;
				//outColor.a = a;// crystals of displacement
				//outColor.a = .0;

				//if(prevScreenColor.a >-0.5){// don't paint on erasure, unless you erase on erasure, or you displace vertices.
				//if( !(prevScreenColor.a > .3 && prevScreenColor.a <.7) ){// don't paint on erasure, unless you erase on erasure, or you displace vertices.
					
					// just paint
					if( //(prevColor.a == 0.0 || prevColor.a ==.8) &&
						_BrushBuffer_P3DA[i].brushMode.x == .8)
					{
						
						//outColor.a = 0.80;// + packedAlpha;
						a*=outColor.a;
						temprgb.xyz = _BrushBuffer_P3DA[i].color.xyz * a + temprgb.rgb * (1.0 - a); 
					}
			

					#ifdef _CUSTOM_VERTEX_DISPLACEMENT_
					else
					if(// (prevColor.a == 0.0 || prevColor.a ==.4) &&
						_BrushBuffer_P3DA[i].brushMode.x == .4)
					{
						//TODO: you might want to vertex displace without overriding the .a
						//outColor.a = .40;// + packedAlpha;
						a *= .1;
						displacementCol.a += a;

						// how do I pack (negative) positions in a 01 texture?
						//float3 dispPos = _BrushBuffer_P3DA[i].color.xyz;
						float3 brushPos =  _PositionWS_P3DA[i].xyz;
						brushPos = mul(unity_WorldToObject, brushPos);
						float3 pixelOPos = mul(unity_WorldToObject, pxPosWorld);
						//float3 pixelWPos = pxPosWorld;//+_WPosNegativeRangeOffset;
						
						//float3 dispDir = normalize(pixelWPos - brushPos);
						////float3 dispPos = lerp(pixelWPos, brushPos, a*_VertexDispScale+_VertexDispScale);
						//TODO: might need to convert dispDir to objectSpace.
						//dispDir = mul(unity_WorldToObject, dispDir) * a; 
						float3 dispDir = normalize(brushPos - (pixelOPos + (displacementCol.xyz*2-1)));
						/*
						//dispDir += (displacementCol.rgb *2 - 1) * (1-a);
						//dispDir = normalize(dispDir);
						//dispDir = lerp(displacementCol.xyz, dispDir, a);

						dispDir = (dispDir+1)/2;
						//displacementCol.xyz = dispDir * a + displacementCol.rgb * (1.0 - a);
						//displacementCol.xyz = lerp(displacementCol.xyz, dispDir,a);
						displacementCol.xyz += dispDir;
						*/
						displacementCol.xyz = (((dispDir) * _HeightMapStrength_P3DA *a)+1)/2;
						
						displacedTF = 1;
						//asdf
					}
					#endif
					

					//int alphaFlag = (int)(floor(output.a*10)/10);
					//float r_g_b_mean = (output.r + output.g + output.b)/3;
					//float packedAlpha = 0;//floor(outColor.a)/100 + frac(outColor.a)/1000;
					#ifdef _BLEND_2_TEXTURES_WITH_PAINT_
						/*
						flags:
							.8 = just paint
							.7 = none
							.6 = blend 2 textures mode
							.5 = nothing
							.4 = vertex heightmap + paint
							.3 = none
							.2 = erase mesh mode

							.xyyyyyyyyy -> y = alpha
						*/
						//if(_PaintingParams_P3DA[i].w == .6 || _BrushBuffer_P3DA[i].brushMode.x == .6)
						else
						if(//	!(alphaFlag > .1 && alphaFlag < .9) &&
							//prevScreenColor.a >0.5 &&
								//(tex2D(_OverlayTex_Before_P3DA, mainUV).a > 0.0 ||
								//prevColor.a == 0.0 || prevColor.a ==.6) &&
							_BrushBuffer_P3DA[i].brushMode.x == .6)
						{
							//outColor.a = 0.60;// + packedAlpha;
							float4 overlayTexAfter = tex2D(_OverlayTex_After_P3DA, mainUV);
							a *= overlayTexAfter.a*outColor.a;
							temprgb.xyz = overlayTexAfter.xyz * a + temprgb.rgb * (1.0 - a)
							;
						}	
					#endif

					#ifdef _ERASE_MESH_WITH_PAINT_
						//if(_PaintingParams_P3DA[i].w == .5 || _BrushBuffer_P3DA[i].brushMode.x == .5)
						else
						//if((prevScreenColor.a == 0 || prevScreenColor.a >.38 && prevScreenColor.a <.59) &&
						if(//(prevColor.a <.19) &&
							_BrushBuffer_P3DA[i].brushMode.x == .2)
						{
							//outColor.a *= 1-a;//0.20;// + packedAlpha;
							outColor.a -= a;

							//temprgb.xyz = _BrushBuffer_P3DA[i].color.xyz * a + temprgb.rgb * (1.0 - a);
						}
					#endif
				//}


	
			
			}
		}

		/*
		#ifdef _CUSTOM_VERTEX_DISPLACEMENT_
		float dott = dot(toolToPixelDirWS, normalws);
		if(dott < 0){
			outColor.a += 0.01;// 0.01 means this was painted on a backface
		}
		else{
			outColor.a = 0.02;// 0.02 means this was painted on a frontface
		}
		#endif
		*/


	}


	//prevColor.rgb = temprgb;
	// TODO: have lerp _Init_P3DA????
	outColor.rgb = lerp(temprgb.rgb, max(outColor.rgb, temprgb.rgb), _Init_P3DA);
	//outColor.rgb = temprgb.rgb;
	///outColor.rgb = prevColor.rgb;
	///outColor = float4(0,0,1,1);

	//outColor.x = 0;
	//outColor.y = outdf.x;		
	//outColor.z = 0;
	//outColor = _PositionWS_P3DA[0]+_PositionWS_P3DA[1];
	
	
	_MainTexInternal_P3DA[mainUVRWT] = outColor;

	#ifdef _CUSTOM_VERTEX_DISPLACEMENT_
		if(displacedTF){
			_DisplacementTexInternal_P3DA[mainUVRWT] = displacementCol;
		}
	#endif
	
	///_MainTexScreen_P3DA
	///clip(-1);
	///outColor = float4(0,0,1,1);
	return outColor;
	///return _MainTexInternal_P3DA[mainUVRWT];

}

float4 Paint3DAccumulatorFragmentLogic_P1(v2f_P3DA i){
	#ifdef UNITY_REQUIRE_FRAG_WORLDPOS
	float3 pxPosWorld = (i.worldPos.xyz);
	#else
	float3 pxPosWorld = float3(1,0,1);// this shader branch should not be reached
	#endif


	float2 uv = i.uv0;
	float2 uvRT = _UVsToUse_P3DA == 0 ? i.uv0 : i.uv1;
	uvRT = uvRT*_Atlas_ST_PerMaterial_P3DA.xy + _Atlas_ST_PerMaterial_P3DA.zw;
	float2 mainUV = uv*_MainTex_P3DA_ST.xy + _MainTex_P3DA_ST.zw;
	float2 mainUVRT = uvRT;///_MainTex_ST.xy - _MainTex_ST.zw;
	int coordx = int((mainUVRT.x)*_RT_Resolution.x);
	int coordy = int((mainUVRT.y)*_RT_Resolution.y);
	int2 mainUVRWT = int2(coordx,coordy);
	float4 mainTex = tex2D(_MainTex_P3DA, mainUV);
	float4 output = _MainTexInternal_P3DA[mainUVRWT];
	#ifndef _RUNNING_IN_PLAY_MODE_
		output.a = 1;
	#endif
	//float alphaFlag = frac(floor(output.a*10)/10);
	//output.a = 1;
	//#if defined(_BLEND_2_TEXTURES_WITH_PAINT_) || defined(_ERASE_MESH_WITH_PAINT_)
	//float r_g_b_mean = (output.r + output.g + output.b)/3;
	//float r_g_b_max = max(output.r,max(output.g,output.b));
	float r_g_b_fade = output.r+output.g+output.b +mainTex.r+mainTex.g+mainTex.b;//min(output.r,min(output.g,output.b));
	//float oneMinus_r_g_b_max = 1 - r_g_b_max;
	//float oneMinus_r_g_b_max_timesA = (1 - r_g_b_max)*output.a;
	float oneMinus_r_g_b_fade_timesA = (1-r_g_b_fade)*output.a;
	//float r_g_b_add = output.r+output.g+output.b;
	
	//output.a = frac(floor(output.a*10)/10)*10 + (frac(output.a*10));
	//output = lerp(mainTex,_MainTexInternal_P3DA[mainUVRWT],clamp(((output.x+output.y+output.z)/3)*4,0,1));
	//output = lerp(mainTex,_MainTexInternal_P3DA[mainUVRWT], max(output.x,max(output.y,output.z)));
	//output = lerp(output, mainTex, oneMinus_r_g_b_max_timesA);
	//output = lerp(mainTex, output, output.a);
	output.rgb = mainTex.rgb + output.rgb;
	

	//float alpha = output.a;

	//float4 output = _MainTexInternal_P3DA[mainUVRWT];
	
	//#endif
	#ifdef _BLEND_2_TEXTURES_WITH_PAINT_
		/*
		flags:
			.8 = just paint
			.7 = none
			.6 = blend 2 textures mode
			.5 = nothing
			.4 = vertex heightmap + paint
			.3 = none
			.2 = erase mesh mode

			.xyyyyyyyyy -> y = alpha
		*/
		float2 blendUV = uv*_OverlayTex_Before_P3DA_ST.xy + _OverlayTex_Before_P3DA_ST.zw;
		float4 overlayTexBefore = tex2D(_OverlayTex_Before_P3DA, blendUV);
		output.rgb = lerp(output.rgb, overlayTexBefore.rgb, overlayTexBefore.a * (oneMinus_r_g_b_fade_timesA));
		//output.rgb = output.rgb + overlayTexBefore * overlayTexBefore.a * (oneMinus_r_g_b_min_timesA);
		/*
		if(alphaFlag == .6)
		{
			float4 overlayTexAfter = tex2D(_OverlayTex_After_P3DA, mainUV);
			
			output.rgb = lerp(output.rgb, overlayTexAfter, saturate(r_g_b_max*overlayTexAfter.a)+_PaintingParams_P3DA[0].w);
			//r_g_b_max = max(output.r,max(output.g,output.b));
		}
		*/
	#endif
	/*
	#ifdef _ERASE_MESH_WITH_PAINT_
		//if(alphaFlag >= .41 && alphaFlag <= .59)//TODO: THIS IS SUPPOSED TO ALWAYS BE .5 DA FUQ. For .6 it works.
		//if(alphaFlag != .6 && alphaFlag > .10 && alphaFlag < .59)
		//if(alphaFlag > .38 && alphaFlag < .59)
		if(alphaFlag > 0.0 && 
		alphaFlag <= .22)
		//if(alphaFlag > .41 && alphaFlag < .59)
		{
			//output.a = 1-(r_g_b_add+_PaintingParams_P3DA[0].w);//r_g_b_max;
			//output.a = alpha = 1-r_g_b_max;
			//alpha = 0;
			output.rgba*= saturate(1-r_g_b_max*1.5);
			//output.a = 0.0;
			//output.a = alpha = 0;

			//alphaFlag = 0;
		}
		else if(alphaFlag == 0.0 ){
			output.a = 1;
		}
	#else

		if(alphaFlag == 0.0 ){
			output.a = 1;
		}
	#endif
	*/

	
	float3 temprgb = float3(0, 0, 0);// output.rgb;
	//float3 temprgb = _MainTexInternal_P3DA[mainUVRWT];
	//float2 outdf = float2(1,0);

	#ifdef _GPU_COLOR_PICKER_ 
	float4 sampledColor = tex2D(_ColorPicker_P3DA, uv*_ColorPicker_P3DA_ST.xy + _ColorPicker_P3DA_ST.zw);
	#endif
	
	#ifdef _DISPLAY_BRUSH_VOLUME_
	for (int i = 0; i < BRUSH_COUNT_P3DA; i++)
	{

		float3 pos = pxPosWorld;

		float2 dims = _ConeShapeXY_P3DA.xy;

		float2 blend;
		float cylinderDFv;
		GetBrushSDFToolShell(i, dims, pos, blend, cylinderDFv);


		#ifdef _GPU_COLOR_PICKER_
		if (
			sampledColor.a > 0.0
			)
		{
			float blendS = max(blend.x, (-cylinderDFv)*sampledColor.a);
			blend.x = blendS;

			float dist = distance(float2(_PositionSS_P3DA[i].x*_ColorSampleDist_P3DA_ST.z, _PositionSS_P3DA[i].y*_ColorSampleDist_P3DA_ST.w), _ColorSampleDist_P3DA_ST.xy);

			if ((cylinderDFv) < _ColorSampleThresh_P3DA
				&& (_PaintingParams_P3DA[i].y > 0 || _PaintingParams_P3DA[i].x > 0)
				&& dist < _ColorSampleDist_P3DA
				)
			{
			
				_BrushBuffer_P3DA[i].color.xyz = sampledColor.rgb;
				
			}
		}
		#endif

		float a = pow(blend.x, 0.8);
		float lv = a;// *0.5 + 0.5;
						//lv = pow(lv,0.85);
						//float3 ringCol = lerp(float3(1, 1, 1) - _BrushBuffer_P3DA[i].color.xyz, _BrushBuffer_P3DA[i].color.xyz, lv);
						//float3 ringCol = lerp(float3(1,1,1), _BrushBuffer_P3DA[i].color.xyz, lv);

		float4 ringCol = tex2D(_ToolOutlineTex_P3DA, lv.xx*_ToolOutlineTex_P3DA_ST.xy + _ToolOutlineTex_P3DA_ST.zw);
		ringCol.xyz = ringCol.xyz * ringCol.a + _BrushBuffer_P3DA[i].color * (1 - ringCol.a);

		/*
		if (distance(float2(_PositionSS_P3DA[0].x*_ColorSampleDist_P3DA_ST.z, _PositionSS_P3DA[0].y*_ColorSampleDist_P3DA_ST.w), _ColorSampleDist_P3DA_ST.xy) < _ColorSampleDist_P3DA)
		{
			ringCol.xyz = float3(1, 0, 0);
			//visible feedback for when you can sample?
		}
		*/
		temprgb.xyz = ringCol * a + temprgb.rgb * (1 - a);
		//float debug = distance(pxPosWorld,_PositionWS_P3DA[i]);
		//temprgb.xyz += debug*debug*debug*0.1;


		
	}
	#endif

	#ifdef _GPU_COLOR_PICKER_
	float4 colorPickerDisplayTex = tex2D(_ColorPickerDisplay_P3DA, uv*_ColorPicker_P3DA_ST.xy + _ColorPicker_P3DA_ST.zw);
	//dicolorPickerDisplayTexspTex = float4(0,0,0,1);
	//temprgb.xyz = colorPickerDisplayTex.rgb * colorPickerDisplayTex.a + temprgb.xyz * (1 - colorPickerDisplayTex.a);
	temprgb.xyz = (output.rgb*(1 - colorPickerDisplayTex.a) + colorPickerDisplayTex.rgb*colorPickerDisplayTex.a) + temprgb;
	#else
	temprgb.xyz = output.rgb + temprgb;
	#endif




	output.rgb = temprgb.xyz;
	//output.rgba = 1;
	//output.a = alpha;
	//output.rgb = pxPosWorld.xyz;
	//output.rgb = _MainTexInternal_P3DA[mainUV];


	//_MainTexInternal_P3DA[mainUV] = outColor;
	
	

	//output.r = 0;
	//output.g = distance(pxPosWorld, _PositionWS_P3DA[0]);
	//output.b = distance(pxPosWorld, _PositionWS_P3DA[1]);
	//output.r = outdf;
	_MainTexScreen_P3DA[mainUVRWT] = output;//_PositionWS_P3DA[0]+_PositionWS_P3DA[1];//output.rgba;
	//_MainTexScreen_P3DA[int2(coordx,coordy)] += float4(0.1,0.1,0.1,1);//_PositionWS_P3DA[0]+_PositionWS_P3DA[1];//output.rgba;
	//output = _MainTexScreen_P3DA[int2(coordx,coordy)];
	
	// _MainTexScreen_P3DA[int2(0,0)] = output.rgba;
	// _MainTexScreen_P3DA[int2(1,1)] = output.rgba;
	// _MainTexScreen_P3DA[int2(2,2)] = output.rgba;
	// _MainTexScreen_P3DA[int2(3,3)] = output.rgba;
	// _MainTexScreen_P3DA[int2(4,4)] = output.rgba;
	// _MainTexScreen_P3DA[int2(5,5)] = output.rgba;
	// _MainTexScreen_P3DA[int2(1,2)] = output.rgba;
	// _MainTexScreen_P3DA[int2(1,3)] = output.rgba;

	//clip(-1);
	//output = float4(mainUV.x, mainUV.y, 0,1);
	//uint2 temp = float2(0,0);
	//_MainTexScreen_P3DA.GetDimensions(temp.x, temp.y);
	//output = float4(temp.x, temp.y, 0, 1);
	//output = _MainTexScreen_P3DA[int2(coordx,coordy)];

	//_BrushBuffer_P3DA[i].color.xyz =  _Color_P3DA;
	//output = alphaFlag;
	
	return output;
}


//-------------------------------------------------------------------------------------

// UBER
inline float3 DeferredLightDir( in float3 worldPos )
{
	#ifndef USING_LIGHT_MULTI_COMPILE
		return _WorldSpaceLightPosCustom.xyz - worldPos.xyz * _WorldSpaceLightPosCustom.w;
	#else
		#ifndef USING_DIRECTIONAL_LIGHT
		return _WorldSpaceLightPosCustom.xyz - worldPos.xyz;
		#else
		return _WorldSpaceLightPosCustom.xyz;
		#endif
	#endif
}

//-------------------------------------------------------------------------------------
UnityLight MainLight ()
{
	UnityLight l = (UnityLight)0;

	l.color = _LightColor0.rgb;
	l.dir = _WorldSpaceLightPos0.xyz;

	return l;
}

UnityLight AdditiveLight (float3 lightDir, float atten)
{
	UnityLight l = (UnityLight)0;

	l.color = _LightColor0.rgb;
	l.dir = lightDir;
	l.dir = normalize(l.dir);

	// shadow the light
	l.color *= atten;
	return l;
}

UnityLight DummyLight ()
{
	UnityLight l = (UnityLight)0;
	l.color = 0;
	l.dir = float3 (0,1,0);

	return l;
}


UnityIndirect ZeroIndirect ()
{
	UnityIndirect ind;
	ind.diffuse = 0;
	ind.specular = 0;
	return ind;
}

//-------------------------------------------------------------------------------------

#if !defined(DISTANCE_MAP) && (defined(_POM_DISTANCE_MAP) || defined(_POM_DISTANCE_MAP_ZWRITE) || defined(_POM_DISTANCE_MAP_SHADOWS))
	#define DISTANCE_MAP
#endif

#if !defined(EXTRUSION_MAP) && (defined(_POM_EXTRUSION_MAP) || defined(_POM_EXTRUSION_MAP_ZWRITE) || defined(_POM_EXTRUSION_MAP_SHADOWS))
	#define EXTRUSION_MAP
#endif

#if !defined(POM) && (defined(_PARALLAX_POM) || defined(_PARALLAX_POM_ZWRITE) || defined(_PARALLAX_POM_SHADOWS))
	#define POM
#endif

#if !defined(TRIPLANAR) && (defined(TRIPLANAR_SELECTIVE))
	#define TRIPLANAR
#endif

#if (defined(_PARALLAX_POM_ZWRITE) || defined(_POM_DISTANCE_MAP_ZWRITE) || defined(_POM_EXTRUSION_MAP_ZWRITE)) && !defined(ZWRITE)
	#define ZWRITE 1
#endif

// UBER
#if UNITY_SPECCUBE_BOX_PROJECTION || UNITY_LIGHT_PROBE_PROXY_VOLUME || defined(POM) || defined(_TRANSLUCENCY) || defined(_GLITTER) || defined(_SNOW) || defined(DISTANCE_MAP) || defined(EXTRUSION_MAP) || defined(_WETNESS) || defined(TRIPLANAR_SELECTIVE)
	#pragma multi_compile __ UNITY_REQUIRE_FRAG_WORLDPOS
	// 1
#else
	#pragma multi_compile __ UNITY_REQUIRE_FRAG_WORLDPOS
	// 0
#endif

#ifdef UNITY_REQUIRE_FRAG_WORLDPOS
	#define IN_WORLDPOS(i) i.posWorld.xyz
	#define IN_WORLDPOSADD(i) i.posWorld.xyz
#else
	#define IN_WORLDPOS(i) float3(0,0,0)
	#define IN_WORLDPOSADD(i) float3(0,0,0)
#endif

#if ( defined(ZWRITE) || (defined(_SNOW) && (defined(POM) || defined(DISTANCE_MAP) || defined(EXTRUSION_MAP))) ) && !defined(TRIPLANAR_SELECTIVE)
	#if !defined(RAYLENGTH_AVAILABLE)
		#define RAYLENGTH_AVAILABLE
	#endif
#endif

#if !defined(DEPTH_SEMANTIC)
	#if defined(SHADER_API_D3D11) && (SHADER_TARGET>=50) && CONSERVATIVE_DEPTH_WRITE
		#define DEPTH_SEMANTIC SV_DepthGreaterEqual
	#else
		#define DEPTH_SEMANTIC SV_Depth
	#endif
#endif

#define FRAGMENT_SETUP(x) FragmentCommonData x = \
	FragmentSetup(i.tex, eyeVec, worldNormal, i_viewDirForParallax, _TBN, IN_WORLDPOS(i), i.vertex_color, _ddx, _ddy, _ddxDet, _ddyDet, tangentBasisScaled, SclCurv, blendFade, actH, diffuseTint, diffuseTint2); // UBER - additional params added

#define FRAGMENT_SETUP_FWDADD(x) FragmentCommonData x = \
	FragmentSetup(i.tex, eyeVec, worldNormal, i_viewDirForParallax, _TBN, IN_WORLDPOSADD(i), i.vertex_color, _ddx, _ddy, _ddxDet, _ddyDet, tangentBasisScaled, SclCurv, blendFade, actH, diffuseTint, diffuseTint2); // UBER - additional params added

struct FragmentCommonData
{
	float3 diffColor, specColor;
	// Note: smoothness & oneMinusReflectivity for optimization purposes, mostly for DX9 SM2.0 level.
	// Most of the math is being done on these (1-x) values, and that saves a few precious ALU slots.
	// (UBER - comment: oneMinusReflectivity is like shader forge "1-specular monochrome")
	float oneMinusReflectivity, smoothness;
	float3 normalWorld, eyeVec, posWorld;
	float alpha;
	// UBER
	float3 pureAlbedo; // used for translucency (w/o energy conservation)
	float3 additionalEmission;
	// needed for SS
	#if defined(_PARALLAX_POM_SHADOWS) || defined(_POM_DISTANCE_MAP_SHADOWS) || defined(_POM_EXTRUSION_MAP_SHADOWS)
	float4 rayPos;
	float3x3 tanToWorld;
	#endif
	float2 texture2ObjectRatio;
	#if defined(_WETNESS)
	float Wetness;
	#endif	
	#if defined(_SNOW)
	float snowVal;
	float dissolveMaskValue;
	#endif	
	#if defined(ZWRITE)
	float rayLength;
	#endif
};

#ifndef UNITY_SETUP_BRDF_INPUT
	#define UNITY_SETUP_BRDF_INPUT SpecularSetup
#endif

void SetupUBER_VertexData_TriplanarWorld(float3 normalWorld, inout float4 i_tangentToWorldAndParallax0, inout float4 i_tangentToWorldAndParallax1, inout float4 i_tangentToWorldAndParallax2) {
	i_tangentToWorldAndParallax0.xyz = cross(normalWorld,cross(normalWorld, float3(0,0,1))); // tangents in world space
	i_tangentToWorldAndParallax0.xyz *= normalWorld.x<0 ? -1:1;
	i_tangentToWorldAndParallax1.xyz = cross(normalWorld,cross(normalWorld, float3(1,0,0)));
	i_tangentToWorldAndParallax1.xyz *= normalWorld.y<0 ? -1:1;
	i_tangentToWorldAndParallax2.xyz = cross(normalWorld,cross(normalWorld, float3(0,1,0)));
	i_tangentToWorldAndParallax2.xyz *= normalWorld.z>0 ? 1:-1;
}

void SetupUBER_VertexData_TriplanarLocal(float3 normalObject, inout float4 i_tangentToWorldAndParallax0, inout float4 i_tangentToWorldAndParallax1, inout float4 i_tangentToWorldAndParallax2, out float scaleX, out float scaleY, out float scaleZ) {
	scaleX = length(float3(unity_ObjectToWorld[0][0], unity_ObjectToWorld[1][0], unity_ObjectToWorld[2][0]));
	scaleY = length(float3(unity_ObjectToWorld[0][1], unity_ObjectToWorld[1][1], unity_ObjectToWorld[2][1]));
	scaleZ = length(float3(unity_ObjectToWorld[0][2], unity_ObjectToWorld[1][2], unity_ObjectToWorld[2][2]));

	i_tangentToWorldAndParallax0.xyz = cross(normalObject, cross(normalObject, float3(0,0,1))); // tangents in obj space
	i_tangentToWorldAndParallax0.xyz *= normalObject.x<0 ? -1:1;
	i_tangentToWorldAndParallax1.xyz = cross(normalObject, cross(normalObject, float3(1,0,0)));
	i_tangentToWorldAndParallax1.xyz *= normalObject.y<0 ? -1:1;
	i_tangentToWorldAndParallax2.xyz = cross(normalObject, cross(normalObject, float3(0,1,0)));
	i_tangentToWorldAndParallax2.xyz *= normalObject.z>0 ? 1:-1;
}

void SetupUBER(float4 i_SclCurv, float3 i_eyeVec, float3 i_posWorld, float3 i_posObject, inout float4 i_tex, inout float4 i_tangentToWorldAndParallax0, inout float4 i_tangentToWorldAndParallax1, inout float4 i_tangentToWorldAndParallax2, inout fixed4 vertex_color, out float actH, out float4 SclCurv, out float3 eyeVec, out float3 tangentBasisScaled, out float2 _ddx, out float2 _ddy, out float2 _ddxDet, out float2 _ddyDet, out float blendFade, out float3 i_viewDirForParallax, out float3x3 _TBN, out float3 worldNormal, out float4 texcoordsNoTransform) {
	
	// (out) compiled out when not used
	#if defined(GEOM_BLEND)
		actH=1; // for geom blend - default h is ceil value (but is supposed to be set later in parallax computation or triplanar init setup below)
	#else
		actH=0; // wetness
	#endif

	#if defined(TRIPLANAR_SELECTIVE)
		#if defined(_TRIPLANAR_WORLD_MAPPING)
			float3 normBlend=i_tex.xyz; // world normal
			float3 posUVZ=i_posWorld.xyz;
			float3 blendVal = abs(normBlend);
		#else
			float3 objScale=float3(i_tangentToWorldAndParallax0.w, i_tangentToWorldAndParallax1.w, i_tangentToWorldAndParallax2.w);
			float3 normObj=i_tex.xyz;
			float3 normBlend=normObj;
			float3 normObjScaled=normalize(normObj/objScale);
			float3 posUVZ=i_posObject.xyz*objScale;
			float3 blendVal = abs(normObjScaled);
		#endif
		float3 uvz = posUVZ.xyz*_MainTex_ST.xxx;
		#if RESOLVE_TRIPLANAR_HEIGHT_SEAMS
			float3 hVal = float3(tex2Dgrad(_ParallaxMap, (normBlend.x>0) ? uvz.zy : float2(-uvz.z,uvz.y) RESOLVE_SEAMS_X).PARALLAX_CHANNEL, tex2Dgrad(_ParallaxMap, (normBlend.y>0) ? uvz.xz : float2(-uvz.x,uvz.z) RESOLVE_SEAMS_Y).PARALLAX_CHANNEL, tex2Dgrad(_ParallaxMap, (normBlend.z>0) ? uvz.yx : float2(-uvz.y,uvz.x) RESOLVE_SEAMS_Z).PARALLAX_CHANNEL);
			#if defined(_TWO_LAYERS)
				float3 uvz2 = posUVZ.xyz*_DetailAlbedoMap_ST.xxx;
				#if defined(_PARALLAXMAP_2MAPS)
					float3 hVal2 = float3(tex2Dgrad(_ParallaxMap2, (normBlend.x>0) ? uvz2.zy : float2(-uvz2.z,uvz2.y) RESOLVE_SEAMS_X).PARALLAX_CHANNEL, tex2Dgrad(_ParallaxMap2, (normBlend.y>0) ? uvz2.xz : float2(-uvz2.x,uvz2.z) RESOLVE_SEAMS_Y).PARALLAX_CHANNEL, tex2Dgrad(_ParallaxMap2, (normBlend.z>0) ? uvz2.yx : float2(-uvz2.y,uvz2.x) RESOLVE_SEAMS_Z).PARALLAX_CHANNEL);
				#else
					float3 hVal2 = float3(tex2Dgrad(_ParallaxMap2, (normBlend.x>0) ? uvz2.zy : float2(-uvz2.z,uvz2.y) RESOLVE_SEAMS_X).PARALLAX_CHANNEL_2ND_LAYER, tex2Dgrad(_ParallaxMap2, (normBlend.y>0) ? uvz2.xz : float2(-uvz2.x,uvz2.z) RESOLVE_SEAMS_Y).PARALLAX_CHANNEL_2ND_LAYER, tex2Dgrad(_ParallaxMap2, (normBlend.z>0) ? uvz2.yx : float2(-uvz2.y,uvz2.x) RESOLVE_SEAMS_Z).PARALLAX_CHANNEL_2ND_LAYER);
				#endif
				hVal = lerp( hVal2, hVal, __VERTEX_COLOR_CHANNEL_LAYER);
			#endif
		#else
			float3 hVal = float3(tex2D(_ParallaxMap, (normBlend.x>0) ? uvz.zy : float2(-uvz.z,uvz.y) ).PARALLAX_CHANNEL, tex2D(_ParallaxMap, (normBlend.y>0) ? uvz.xz : float2(-uvz.x,uvz.z) ).PARALLAX_CHANNEL, tex2D(_ParallaxMap, (normBlend.z>0) ? uvz.yx : float2(-uvz.y,uvz.x) ).PARALLAX_CHANNEL);
			#if defined(_TWO_LAYERS)
				float3 uvz2 = posUVZ.xyz*_DetailAlbedoMap_ST.xxx;
				#if defined(_PARALLAXMAP_2MAPS)
					float3 hVal2 = float3(tex2D(_ParallaxMap2, (normBlend.x>0) ? uvz2.zy : float2(-uvz2.z,uvz2.y) ).PARALLAX_CHANNEL, tex2D(_ParallaxMap2, (normBlend.y>0) ? uvz2.xz : float2(-uvz2.x,uvz2.z) ).PARALLAX_CHANNEL, tex2D(_ParallaxMap2, (normBlend.z>0) ? uvz2.yx : float2(-uvz2.y,uvz2.x) ).PARALLAX_CHANNEL);
				#else
					float3 hVal2 = float3(tex2D(_ParallaxMap2, (normBlend.x>0) ? uvz2.zy : float2(-uvz2.z,uvz2.y) ).PARALLAX_CHANNEL_2ND_LAYER, tex2D(_ParallaxMap2, (normBlend.y>0) ? uvz2.xz : float2(-uvz2.x,uvz2.z) ).PARALLAX_CHANNEL_2ND_LAYER, tex2D(_ParallaxMap2, (normBlend.z>0) ? uvz2.yx : float2(-uvz2.y,uvz2.x) ).PARALLAX_CHANNEL_2ND_LAYER);
				#endif
				hVal = lerp( hVal2, hVal, __VERTEX_COLOR_CHANNEL_LAYER);
			#endif
		#endif
		
		blendVal += _TriplanarHeightmapBlendingValue*hVal;
		blendVal /= dot(blendVal,1);
		
		float maxXY = max(blendVal.x,blendVal.y);
		float3 tri_mask = (blendVal.x>blendVal.y) ? float3(1,0,0) : float3(0,1,0);
		tri_mask = (blendVal.z>maxXY) ? float3(0,0,1) : tri_mask;
		
		// inited here, reused in parallax function		
		#if defined(_TWO_LAYERS)
			// need to call GetH to set height blending between layers
			{
			float2 control=float2(__VERTEX_COLOR_CHANNEL_LAYER, 1-__VERTEX_COLOR_CHANNEL_LAYER);
			float2 hgt=float2(dot(hVal2, blendVal), dot(hVal, blendVal));
			control*=hgt+0.01;			// height evaluation
			control*=control; 			// compress
			control/=dot(control,1);	// normalize
			control*=control;			// compress
			control*=control;			// compress
			control*=control;			// compress
			control/=dot(control,1);	// normalize
			
			__VERTEX_COLOR_CHANNEL_LAYER=control.x; // write blending value back into the right vertex_color channel variable
			actH = lerp(hgt.x, hgt.y, __VERTEX_COLOR_CHANNEL_LAYER);
			}
		#else
			actH = dot(hVal, blendVal);
		#endif
		
		blendVal.xy = blendVal.y > blendVal.x ? blendVal.yx : blendVal.xy;
		blendVal.yz = blendVal.z > blendVal.y ? blendVal.zy : blendVal.yz;
		blendVal.xy = blendVal.y > blendVal.x ? blendVal.yx : blendVal.xy;
		// now blendVal.x = max , blendVal.y = mid, blendVal.z = min from initial blendVal.xyz components
		blendFade = saturate( (blendVal.x-blendVal.y)/blendVal.x*_TriplanarBlendSharpness );
		
		#if defined(_TRIPLANAR_WORLD_MAPPING)
			float3 tangent_flip = tri_mask * ((normBlend.xyz<0) ? float3(1,1,1) : float3(-1,-1,-1));
		#else
			float3 tangent_flip = tri_mask * ((normBlend.xyz>0) ? float3(1,1,1) : float3(-1,-1,-1));
		#endif
		i_tex.xy = float2(tangent_flip.x, tri_mask.x)*posUVZ.zy + float2(tangent_flip.y, tri_mask.y)*posUVZ.xz + float2(tangent_flip.z, tri_mask.z)*posUVZ.yx;
		i_tex.zw = i_tex.xy*_DetailAlbedoMap_ST.xx;
		i_tex.xy *= _MainTex_ST.xx;
		texcoordsNoTransform=0; // secondary occlusion, not used - we have no real texcoords
	#else
		blendFade=0; // not used
		texcoordsNoTransform=i_tex;
		i_tex.zw = TRANSFORM_TEX(((_UVSec == 0) ? i_tex.xy : i_tex.zw), _DetailAlbedoMap);
		if (_UVSec == 2) {
			float3 posUVZ = i_posWorld.xyz;
			float3 blendVal = abs(i_tangentToWorldAndParallax2.xyz);

			float maxXY = max(blendVal.x, blendVal.y);
			float3 tri_mask = (blendVal.x>blendVal.y) ? float3(1, 0, 0) : float3(0, 1, 0);
			tri_mask = (blendVal.z>maxXY) ? float3(0, 0, 1) : tri_mask;

			float2 uv2World = tri_mask.x*posUVZ.zy + tri_mask.y*posUVZ.xz + tri_mask.z*posUVZ.yx;
			i_tex.zw = TRANSFORM_TEX(uv2World, _DetailAlbedoMap);
		}
		i_tex.xy = TRANSFORM_TEX(i_tex.xy, _MainTex); // Always source from uv0
	#endif
	
	// UBER
	#if defined(TRIPLANAR_SELECTIVE)
		float3 _ddx3=ddx(uvz);
		_ddx = tri_mask.xx*_ddx3.zy + tri_mask.yy*_ddx3.xz + tri_mask.zz*_ddx3.yx;
		
		float3 _ddy3=ddy(uvz);
		_ddy = tri_mask.xx*_ddy3.zy + tri_mask.yy*_ddy3.xz + tri_mask.zz*_ddy3.yx;
		
		_ddxDet=_ddx/_MainTex_ST.xx*_DetailAlbedoMap_ST.xx;
		_ddyDet=_ddy/_MainTex_ST.xx*_DetailAlbedoMap_ST.xx;
	#elif defined(POM) || defined(_SNOW) || defined(_GLITTER) || defined(DISTANCE_MAP) || defined(EXTRUSION_MAP)
		_ddx=ddx(i_tex.xy);
		_ddy=ddy(i_tex.xy);
		_ddxDet=ddx(i_tex.zw);
		_ddyDet=ddy(i_tex.zw);
	#else
		_ddx=0;
		_ddy=0;
		_ddxDet=0;
		_ddyDet=0;
	#endif	

	#if defined(RAYLENGTH_AVAILABLE)
		// we need to go from tangent to world space for zwrite and parallaxed snow (actually when snow is mapped in worldspace)
		tangentBasisScaled=float3(length(i_tangentToWorldAndParallax0.xyz), length(i_tangentToWorldAndParallax1.xyz), length(i_tangentToWorldAndParallax2.xyz));
		i_tangentToWorldAndParallax0.xyz/=tangentBasisScaled.x; // here we can normalize it
		i_tangentToWorldAndParallax1.xyz/=tangentBasisScaled.y;
		i_tangentToWorldAndParallax2.xyz/=tangentBasisScaled.z;
//		tangentBasisScaled=0.4;
	#else
		tangentBasisScaled=1; // not used
	#endif

	#if defined(TRIPLANAR_SELECTIVE) && !defined(_TRIPLANAR_WORLD_MAPPING)
		SclCurv = 0; // not used
		eyeVec = i_posWorld.xyz - _WorldSpaceCameraPos; // will be normalized in FRAGMENT_SETUP()
	#elif defined(POM) || defined(DISTANCE_MAP) || defined(EXTRUSION_MAP)
		eyeVec = i_posWorld.xyz - _WorldSpaceCameraPos; // will be normalized in FRAGMENT_SETUP()
		SclCurv = i_SclCurv;
	#else
		SclCurv = 0; // not used
		eyeVec = i_eyeVec;
	#endif

	#if defined(TRIPLANAR_SELECTIVE)
		#if defined(_TRIPLANAR_WORLD_MAPPING)
		
			// TBN in world space
			worldNormal=normBlend; // world normal
			float3 _tangent=tri_mask.xxx*i_tangentToWorldAndParallax0.xyz + tri_mask.yyy*i_tangentToWorldAndParallax1.xyz + tri_mask.zzz*i_tangentToWorldAndParallax2.xyz;
			float3 _binormal=cross(worldNormal, _tangent);
			_TBN = float3x3(_tangent, _binormal, worldNormal);
			
			eyeVec = normalize(i_eyeVec);
			#if defined(_PARALLAXMAP) || defined(_PARALLAXMAP_2MAPS)
				i_viewDirForParallax=mul(_TBN, eyeVec);
				i_viewDirForParallax.z=-i_viewDirForParallax.z;
			#else
				i_viewDirForParallax=float3(0,0,0);
			#endif
			
		#else
		
			float3 _normal=normObj;
			float3 _tangent=tri_mask.xxx*i_tangentToWorldAndParallax0.xyz + tri_mask.yyy*i_tangentToWorldAndParallax1.xyz + tri_mask.zzz*i_tangentToWorldAndParallax2.xyz;
			float3 _binormal=cross(_normal, _tangent);
			
			#if defined(_PARALLAXMAP) || defined(_PARALLAXMAP_2MAPS)
				// TBN in object space
				float3x3 rotation=float3x3(_tangent, -_binormal, _normal);
				i_viewDirForParallax=normalize( mul(rotation, ObjSpaceViewDir(float4(i_posObject,1)) ) );
			#else
				i_viewDirForParallax=float3(0,0,0);
			#endif
			// TBN in world space
			_normal = UnityObjectToWorldNormal(_normal);
			_binormal = UnityObjectToWorldNormal(_binormal);
			_tangent = cross(_normal, _binormal); // basis is orthonormalized
			
			_TBN = float3x3(_tangent, _binormal, _normal);
			worldNormal=_normal;
			
		#endif	
	#else
		#if defined(_PARALLAXMAP) || defined(_PARALLAXMAP_2MAPS) || defined(POM) || defined(DISTANCE_MAP) || defined(EXTRUSION_MAP)
			i_viewDirForParallax=normalize( float3(i_tangentToWorldAndParallax0.w, i_tangentToWorldAndParallax1.w, i_tangentToWorldAndParallax2.w));
		#else
			i_viewDirForParallax=float3(0,0,0);
		#endif	
		_TBN=ExtractTangentToWorldPerPixel(i_tangentToWorldAndParallax0, i_tangentToWorldAndParallax1, i_tangentToWorldAndParallax2);
		worldNormal=i_tangentToWorldAndParallax2.xyz;
	#endif
}

inline FragmentCommonData SpecularSetup (float4 i_tex, fixed4 vertex_color, float2 _ddx, float2 _ddy, float2 _ddxDet, float2 _ddyDet, float Wetness, float blendFade, float3 diffuseTint, float3 diffuseTint2) // UBER (params added)
{ 
	float4 specGloss = SpecularGloss(i_tex, vertex_color, _ddx, _ddy, _ddxDet, _ddyDet, Wetness); // UBER - pass 4 components (zw for detail tiling)
	float3 specColor = specGloss.rgb;
	float smoothness = specGloss.a;

	float oneMinusReflectivity;

	float3 additionalEmission=0;
	float3 pureAlbedo=Albedo(i_tex, vertex_color, Wetness, _ddx, _ddy, _ddxDet, _ddyDet, /* inout */ additionalEmission, blendFade, diffuseTint, diffuseTint2);
	float3 diffColor = EnergyConservationBetweenDiffuseAndSpecular (pureAlbedo, specColor, /*out*/ oneMinusReflectivity);

	FragmentCommonData o = (FragmentCommonData)0;
	o.diffColor = diffColor;
	o.specColor = specColor;
	o.pureAlbedo = pureAlbedo;
	o.oneMinusReflectivity = oneMinusReflectivity;
	o.smoothness = smoothness;
	o.additionalEmission = additionalEmission;
	return o;
}

inline FragmentCommonData MetallicSetup (float4 i_tex, fixed4 vertex_color, float2 _ddx, float2 _ddy, float2 _ddxDet, float2 _ddyDet, float Wetness, float blendFade, float3 diffuseTint, float3 diffuseTint2) // UBER - vertex_color, derivatives
{
	float2 metallicGloss = MetallicGloss(i_tex, vertex_color, _ddx, _ddy, _ddxDet, _ddyDet, Wetness); // UBER - pass 4 components (zw for detail tiling)
	float metallic = metallicGloss.x;
	float smoothness = metallicGloss.y;

	float oneMinusReflectivity;
	float3 specColor;

	float3 additionalEmission=0;
	float3 pureAlbedo=Albedo(i_tex, vertex_color, Wetness, _ddx, _ddy, _ddxDet, _ddyDet, /* inout */ additionalEmission, blendFade, diffuseTint, diffuseTint2);
	float3 diffColor = DiffuseAndSpecularFromMetallic (pureAlbedo, metallic, /*out*/ specColor, /*out*/ oneMinusReflectivity);

	FragmentCommonData o = (FragmentCommonData)0;
	o.pureAlbedo = pureAlbedo;
	o.diffColor = diffColor;
	o.specColor = specColor;
	o.oneMinusReflectivity = oneMinusReflectivity;
	o.smoothness = smoothness;
	o.additionalEmission = additionalEmission;
	return o;
} 

// UBER - Translucency
#if defined(_TRANSLUCENCY)
float3 Translucency(FragmentCommonData s, UnityLight light, float translucency_thickness, fixed4 vertex_color) {

	float4 TranslucencyColor=_TranslucencyColor;
	#if defined(_TWO_LAYERS)
		TranslucencyColor=lerp(_TranslucencyColor2, _TranslucencyColor, __VERTEX_COLOR_CHANNEL_LAYER);
	#endif

	#if defined(_SNOW)
		float4 translucencyColor=lerp(TranslucencyColor,_SnowTranslucencyColor, s.snowVal);
	#else
		float4 translucencyColor=TranslucencyColor;
	#endif
	#ifdef USING_DIRECTIONAL_LIGHT
		float tLitDot=saturate(dot( (light.dir + s.normalWorld*_TranslucencyNormalOffset), s.eyeVec) );
	#else
		float3 lightDirectional=normalize(_WorldSpaceLightPos0.xyz - _WorldSpaceCameraPos.xyz);
		light.dir=normalize(lerp(light.dir, lightDirectional, _TranslucencyPointLightDirectionality));
		float tLitDot=saturate( dot( (light.dir + s.normalWorld*_TranslucencyNormalOffset), s.eyeVec) );
	#endif
	
	tLitDot = exp2( -_TranslucencyExponent*(1-tLitDot) ) * _TranslucencyStrength;
	float NDotL = abs(dot(light.dir, s.normalWorld));
	tLitDot *= lerp( 1, NDotL, _TranslucencyNDotL );
	
	float3 pureAlbedo;
	#if defined(_SNOW)
		pureAlbedo=lerp(s.pureAlbedo.rgb, _SnowColorAndCoverage.rgb, s.snowVal);
	#else
		pureAlbedo=s.pureAlbedo.rgb;
	#endif
	float translucencyOcclusion = lerp( 1, translucency_thickness, _TranslucencyOcclusion );
	#if defined(TRANSLUCENCY_VERTEX_COLOR_CHANNEL)
		translucencyOcclusion*=vertex_color.TRANSLUCENCY_VERTEX_COLOR_CHANNEL;
	#endif
	float translucencyAtten = (tLitDot+_TranslucencyConstant*(NDotL+0.1))*translucencyOcclusion;
	#if defined(UBER_TRANSLUCENCY_PER_LIGHT_ALPHA)
	translucencyAtten*=_LightColor0.a;
	#endif
	
	return translucencyAtten * pureAlbedo.rgb * translucencyColor.rgb;
}
#endif

// UBER - Glitter
#if defined(_GLITTER) 
void Glitter(inout FragmentCommonData s, float2 _uv, float2 _ddxDet, float2 _ddyDet, float3 posWorld, fixed4 vertex_color, float glitter_thickness) {
	float2 glitterUV_Offset = (_WorldSpaceCameraPos.xz+posWorld.zx+_WorldSpaceCameraPos.yy+posWorld.yy)*GLITTER_ANIMATION_FREQUENCY*_GlitterTiling;
	float MIP_filterVal = _GlitterTiling*exp2(_GlitterFilter);
	float2 _ddxDetBias=_ddxDet*MIP_filterVal;
	float2 _ddyDetBias=_ddyDet*MIP_filterVal;
	float sparkle=tex2Dgrad(_SparkleMap, _uv*_GlitterTiling + glitterUV_Offset, _ddxDetBias, _ddyDetBias).r;
	float sparkle2=tex2Dgrad(_SparkleMap, _uv*_GlitterTiling - glitterUV_Offset, _ddxDetBias, _ddyDetBias).r;
	sparkle*=lerp(sparkle, 1, _GlitterDensity);
	float sparkleDenseVal=sparkle*sparkle2;// depends on density of sparkle mask
	sparkle2*=lerp(sparkle2, 1, _GlitterDensity);
	
	float3 _color=lerp( float3(0.9,0.9,0.9), abs(frac(s.normalWorld*4)*2-1), _GlitterColorization) + float3(0.5,0.5,0.5);
	_color*=_color;
	
	float sparkleStrengh=sparkle2*sparkle*GLITTER_AMPLIFY; // GLITTER_AMPLIFY defined in UBER_StandardConfig.cginc
	#if defined(_SNOW)
		sparkleStrengh*=s.dissolveMaskValue;
	#endif
	#if defined(VERTEX_COLOR_CHANNEL_GLITTER)
		sparkleStrengh*=vertex_color.VERTEX_COLOR_CHANNEL_GLITTER;
	#endif
	
	_color*=sparkleStrengh*glitter_thickness;
	
	float4 GlitterColor=_GlitterColor;
	#if defined(_TWO_LAYERS)
		GlitterColor=lerp(_GlitterColor2, GlitterColor, __VERTEX_COLOR_CHANNEL_LAYER);	
	#endif
	#if defined(_SNOW)
		float4 SnowGlitterColor = _SnowGlitterColorFromGlobal ? _UBER_GlobalSnowGlitterColor : _SnowGlitterColor;
		_color*=lerp(GlitterColor.rgb, SnowGlitterColor.rgb, s.snowVal);
		float GlitterSmoothnessStrength=lerp(GlitterColor.a, SnowGlitterColor.a, s.snowVal);
	#else
		_color*=GlitterColor.rgb;
		float GlitterSmoothnessStrength=GlitterColor.a;
	#endif
	
	#if defined(VERTEX_COLOR_CHANNEL_GLITTER)
		GlitterSmoothnessStrength*=vertex_color.VERTEX_COLOR_CHANNEL_GLITTER;
	#endif
	
	GlitterSmoothnessStrength*=glitter_thickness;
		
	s.smoothness+=min(GLITTER_SMOOTHNESS_GAIN_LIMIT, sparkleDenseVal*GLITTER_AMPLIFY*GlitterSmoothnessStrength); // GLITTER_SMOOTHNESS_GAIN_LIMIT defined in UBER_StandardConfig.cginc
	s.smoothness=saturate(s.smoothness);
	s.specColor+=_color;
}
#endif

// UBER: inout added (parallaxed i_tex is not propagated outside FragmentSetup function thus emission/occlusion calculated was not parallaxed
inline FragmentCommonData FragmentSetup (inout float4 i_tex, float3 i_eyeVec, float3 i_normalWorld, inout float3 i_viewDirForParallax, inout float3x3 i_tanToWorld, float3 i_posWorld, inout fixed4 vertex_color, float2 _ddx, float2 _ddy, float2 _ddxDet, float2 _ddyDet, float3 tangentBasisScaled, float4 SclCurv, float blendFade, float actH, float3 diffuseTint, float3 diffuseTint2) // UBER - additional params added
{
	float4 rayPos=0; // rayPos from POM parallax (the place we hit the surface in tangent space)
	float2 texture2ObjectRatio=0; // computed in Parallax() we need it for self-shadowing too
	float rayLength=0;
	
	// UBER - snow level - set in NormalInTangentSpace() (might be compiled out when not used)
	// (compiled out when not used)
	float _snow_val = 0;
	float _snow_val_nobump = 0;
	float dissolveMaskValue=0;
	#if defined(_SNOW)
		_snow_val = _SnowColorAndCoverage.a*__VERTEX_COLOR_CHANNEL_SNOW;
		_snow_val *= saturate((i_posWorld.y-_SnowHeightThreshold)/_SnowHeightThresholdTransition);
		_snow_val_nobump = saturate( _snow_val - (1-i_normalWorld.y)*_SnowSlopeDamp );
		
		float snowMaskLargeScale=tex2D(_RippleMap, i_posWorld.xz*SNOW_LARGE_MASK_TILING).g*0.3;
		_snow_val_nobump -= lerp(snowMaskLargeScale, 0, _snow_val_nobump);
		_snow_val_nobump = saturate(_snow_val_nobump);
		float _snow_val_nobump_per_material=_snow_val_nobump; // used later for wet coverage with snow (melting snow)
		_snow_val_nobump *= _SnowLevelFromGlobal ? (1-_UBER_GlobalSnowDamp) : 1;
		_snow_val=_snow_val_nobump;
	#endif		
	
	#if defined(_WETNESS_RIPPLES) || defined(_WETNESS_DROPLETS) || defined(_WETNESS_FULL)
		float2 i_tex_wet=i_posWorld.xz;
		//float3 viewDir=normalize(i_posWorld-_WorldSpaceCameraPos);
		//i_tex_wet-=(1-_WetnessLevel/1.25)*viewDir.xz/viewDir.y; // tutaj b. trudno przeliczyc z world do tangent aby mnoznik po lewej sie zgadzal
		float2 wetUV=i_tex_wet.xy;
		float2 wetDDX=ddx(wetUV);
		float2 wetDDY=ddy(wetUV);
	#endif

	#if defined(DISTANCE_MAP)
		float3 _norm=float3(0,0,1); // will be set in ParallaxPOMDistance() function
		i_tex = ParallaxPOMDistance(i_tex, i_viewDirForParallax, i_posWorld, vertex_color, _ddx, _ddy, _snow_val_nobump, /* inout */ actH, /* inout */ rayPos, /* inout */ texture2ObjectRatio, /* inout */ rayLength, tangentBasisScaled, SclCurv, /* inout */ _norm);
	#elif defined(EXTRUSION_MAP)
		float3 _norm=float3(0,0,1); // will be set in ParallaxPOMExtrusion() function
		i_tex = ParallaxPOMExtrusion(i_tex, i_viewDirForParallax, i_posWorld, vertex_color, _ddx, _ddy, _snow_val_nobump, /* inout */ actH, /* inout */ rayPos, /* inout */ texture2ObjectRatio, /* inout */ rayLength, tangentBasisScaled, SclCurv, /* inout */ _norm);
	#else
		// (i_tanToWorld can be modified by silhouette tracing)
		// NOTE: i_viewDirForParallax is object space view dir here when SILHOUETTE_CURVATURE_MAPPED is defined, will be put into tan space inside parallax function
		i_tex = Parallax(i_tex, /* inout */ i_viewDirForParallax, /* inout */ i_tanToWorld, i_posWorld, /* inout */ vertex_color, _ddx, _ddy, _snow_val_nobump, /* inout */ actH, /* inout */ rayPos, /* inout */ texture2ObjectRatio, /* inout */ rayLength, tangentBasisScaled, SclCurv, blendFade); // UBER - i_tanToWorld, i_posWorld, vertex_color, ddx, ddy, actH, ... added
	#endif
	
	// UBER
	#if defined(_SNOW)
		// needed later in case of snow covering wet surface
		float2 uvDet_no_refr=i_tex.zw;
	#else
		float2 uvDet_no_refr=0;
	#endif
	
	// wet ripples normalmap
	#if defined(_WETNESS)
		float3 wetNorm=float3(0,0,1); 
		float rippleMIPsel = 0;
		float Wetness = 0;
		float WetnessConst = 0;
		float deepWetFct = 0;
		float wetMask = 0;
		#if _DETAIL || defined(_DETAIL_SIMPLE)		
			#if defined(_TWO_LAYERS)
				//wetMask=0; // no detail mask available
			#else
				wetMask=0.1-tex2Dp(_DetailMask, i_tex.zw*_WetnessUVMult, _ddx*_WetnessUVMult, _ddy*_WetnessUVMult).r*0.1;
			#endif
		#endif
		#if defined(_SNOW)
			float additionalWetDamp=_WetnessMergeWithSnowPerMaterial ? _snow_val_nobump_per_material : 1;
			wetMask=wetMask*0.7+snowMaskLargeScale*0.3;
		#else
			float additionalWetDamp=1;
		#endif
		Wetness=saturate( (__VERTEX_COLOR_CHANNEL_WETNESS*additionalWetDamp*_WetnessLevel*(_WetnessLevelFromGlobal ? (1-_UBER_GlobalDry) : 1)-actH-wetMask) * 4 );
		WetnessConst = saturate( (__VERTEX_COLOR_CHANNEL_WETNESS*additionalWetDamp*_WetnessConst*(_WetnessConstFromGlobal ? (1 - _UBER_GlobalDryConst) : 1) + 0.2*_WetnessConst - wetMask * 2) );

		#if defined(_SNOW)
			// snow override wetness
			// (we skip it - let user controll it via vertex colors or global controller)
			//Wetness*=saturate(1-_snow_val*2);
			float refrSnowDamp=1;//saturate(1-_snow_val*8);
		#endif	
		deepWetFct=saturate((Wetness-0.5)*2);	
		
		UBER_Time = _WetnessFlowGlobalTime ? UBER_Time : _Time;
		
		#if defined(_WETNESS_RIPPLES) || defined(_WETNESS_FULL)
		float RippleStrength = _RippleStrengthFromGlobal ? _UBER_RippleStrength*_RippleStrength : _RippleStrength;
		{
			float2 rippleUV=wetUV*_RippleTiling;
			float2 rippleDDX=wetDDX*_RippleTiling;
			float2 rippleDDY=wetDDY*_RippleTiling;

			float animSpeed=_RippleAnimSpeed;
			
			#if WET_FLOW
				// hi freq
				float2 timeOffset = UBER_Time.yy*animSpeed;
				float4 wetVal = tex2Dgrad(_RippleMap, rippleUV + timeOffset, rippleDDX, rippleDDY);
				wetVal += tex2Dgrad(_RippleMap, rippleUV - timeOffset*1.2, rippleDDX, rippleDDY);
				wetVal -= 1; // -1..1
				// lo freq
				rippleUV *= 0.25;
				rippleDDX *= 0.25;
				rippleDDY *= 0.25;
				timeOffset *= 0.5;
				timeOffset.x = -timeOffset.x; // lo freq waves animates across
				float4 wetVal2 = tex2Dgrad(_RippleMap, rippleUV + timeOffset, rippleDDX, rippleDDY);
				wetVal2 += tex2Dgrad(_RippleMap, rippleUV - timeOffset*1.3, rippleDDX, rippleDDY);
				wetVal2 -= 1; // -1..1
				// combine hi+lo freq
				wetVal = (0.5*wetVal + 0.5*wetVal2)*0.5+0.5; // 0..1 for unpack
				wetNorm = UnpackScaleNormal(wetVal, RippleStrength*__VERTEX_COLOR_CHANNEL_WETNESS_RIPPLES);
				float slopeRippleDamp = abs(i_normalWorld.y);
				slopeRippleDamp *= slopeRippleDamp;
				wetNorm.xy *= slopeRippleDamp;
				//wetNorm=normalize(wetNorm);
			#else
				float _Tim=frac(UBER_Time.x*_FlowCycleScale)*2;
				float ft=abs(frac(_Tim)*2 - 1);
				
				#if defined(WATER_FLOW_DIRECTION_FROM_NORMALMAPS)
					#if defined(_TWO_LAYERS)
						float FlowNormStrength = _WetnessNormStrength*saturate(1-i_normalWorld.y*0.5)*saturate(actH*2.5-_WetnessLevel);
						float3 mainBumpsInTangentSpace =  UnpackScaleNormal( tex2Dlod(_BumpMap, float4(i_tex.xy,_WetnessNormMIP.xx)) , FlowNormStrength ) ;
						float3 mainBumpsInTangentSpace2 =  UnpackScaleNormal( tex2Dlod(_BumpMap, float4(i_tex.xy,_WetnessNormMIP.xx)) , FlowNormStrength ) ;
						mainBumpsInTangentSpace = lerp( mainBumpsInTangentSpace2, mainBumpsInTangentSpace, __VERTEX_COLOR_CHANNEL_LAYER );
						mainBumpsInTangentSpace = normalize(mainBumpsInTangentSpace);
					#else
						float3 mainBumpsInTangentSpace = normalize( UnpackScaleNormal( tex2Dlod(_BumpMap, float4(i_tex.xy,_WetnessNormMIP.xx)) , _WetnessNormStrength*saturate(1-i_normalWorld.y*0.5)*saturate(actH*2.5-_WetnessLevel) ) );
					#endif
					float2 slopeXZ = mul(mainBumpsInTangentSpace, i_tanToWorld).xz;
				#else
					float2 slopeXZ = i_normalWorld.xz;
				#endif
				
				float2 flowSpeed=clamp((i_normalWorld.y>0 ? -4:4) * slopeXZ+0.04,-1,1)/_FlowCycleScale;
				flowSpeed*=animSpeed*_RippleTiling;
				
				wetNorm = UnpackScaleNormal(tex2Dgrad(_RippleMap, rippleUV+frac(_Tim.xx)*flowSpeed, rippleDDX, rippleDDY) , RippleStrength*__VERTEX_COLOR_CHANNEL_WETNESS_FLOW);
				wetNorm = lerp(wetNorm, UnpackScaleNormal(tex2Dgrad(_RippleMap, rippleUV+frac(_Tim.xx+0.5)*flowSpeed*1.25, rippleDDX, rippleDDY) , RippleStrength*__VERTEX_COLOR_CHANNEL_WETNESS_FLOW), ft);
				wetNorm.xy*=abs(i_normalWorld.y);//1-exp2(-12*abs(i_normalWorld.y));
				//wetNorm=normalize(wetNorm);
			#endif
			#if defined(_SNOW)
//				wetNorm.xy*=refrSnowDamp;
			#endif
						
			rippleDDX*=_RippleMap_TexelSize.zw*16;
			rippleDDY*=_RippleMap_TexelSize.zw*16;
			float rippleD = max( dot( rippleDDX, rippleDDX ), dot( rippleDDY, rippleDDY ) );
			rippleMIPsel = max(0, log2(rippleD)); // uzyte ponizej do filtrowania IBL
			// additional grazing angle filtering
			float _Fresnel=exp2(-8.65*i_viewDirForParallax.z); // (1-x)^5 aprrox.
			rippleMIPsel += _Fresnel*10;
			
			float rippleReduceRef=saturate(1-(rippleMIPsel*_WetnessSpecGloss.a*RippleStrength*_RippleSpecFilter)*0.5);
			float2 ripple_refraction_offset=rippleReduceRef*_RippleRefraction*wetNorm.xy*0.05*deepWetFct;
			 
			i_tex.xy+=ripple_refraction_offset;
			i_tex.zw+=ripple_refraction_offset*_DetailAlbedoMap_ST.xy/_MainTex_ST.xy;
		}
		#endif

		#if defined(_WETNESS_DROPLETS) || defined(_WETNESS_FULL)
		float2 droplets_refraction_offset;	
		{
			float RainIntensity=_RainIntensityFromGlobal ? (1-_UBER_GlobalRainDamp)*_RainIntensity : _RainIntensity;
		
			float2 rippleUV=wetUV*_DropletsTiling;
			float2 rippleDDX=wetDDX*_DropletsTiling;
			float2 rippleDDY=wetDDY*_DropletsTiling;
		
			fixed4 Ripple = tex2Dp(_DropletsMap, rippleUV, rippleDDX, rippleDDY);
			Ripple.xy = Ripple.xy * 2 - 1;
		
			float DropFrac = frac(Ripple.w + _Time.x*_DropletsAnimSpeed);
			float TimeFrac = DropFrac - 1.0f + Ripple.z;
			float DropFactor = saturate(RainIntensity - DropFrac);
			float FinalFactor = DropFactor * Ripple.z * sin( clamp(TimeFrac * 9.0f, 0.0f, 3.0f) * 3.1415);
			float2 droplets_refraction_offset = Ripple.xy * FinalFactor;
			
			rippleUV+=float2(0.25,0.25);
			Ripple = tex2Dp(_DropletsMap, rippleUV, rippleDDX, rippleDDY);
			Ripple.xy = Ripple.xy * 2 - 1;
		
			DropFrac = frac(Ripple.w + _Time.x*_DropletsAnimSpeed);
			TimeFrac = DropFrac - 1.0f + Ripple.z;
			DropFactor = saturate(RainIntensity - DropFrac);
			FinalFactor = DropFactor * Ripple.z * sin( clamp(TimeFrac * 9.0f, 0.0f, 3.0f) * 3.1415);
			droplets_refraction_offset += Ripple.xy * FinalFactor;
			
			droplets_refraction_offset*=__VERTEX_COLOR_CHANNEL_WETNESS_DROPLETS*(deepWetFct*1.0+WetnessConst*0.0) * 0.1f * abs(i_normalWorld.y);
			wetNorm.xy+=droplets_refraction_offset*10;
			//wetNorm=normalize(wetNorm);
			droplets_refraction_offset*=_RippleRefraction;
			
			#if defined(_SNOW)
				droplets_refraction_offset*=refrSnowDamp;
			#endif
			i_tex.xy+=droplets_refraction_offset;
			i_tex.zw+=droplets_refraction_offset*_DetailAlbedoMap_ST.xy/_MainTex_ST.xy;
		}
		#endif
		
	#else
		// wetness not used
		float Wetness = 0; // compiled out (not used, even if passed to functions)
		float deepWetFct = 0;
		float3 wetNorm = 0;
		float rippleMIPsel = 0;
	#endif	
			
	float3 eyeVec = i_eyeVec;
	#if defined(TRIPLANAR_SELECTIVE) && defined(_TRIPLANAR_WORLD_MAPPING)
		// already normalized
	#else
		{
		eyeVec = Unity_SafeNormalize(eyeVec);
		}
	#endif			
			
	//
	#if _NORMALMAP
		// _snow_val_nobump, i_tanToWorld - needed for snow in NormalInTangentSpace()
		#if defined(_SNOW) && ENABLE_SNOW_WORLD_MAPPING
			#if defined(RAYLENGTH_AVAILABLE)
				float2 snowUV=rayLength*eyeVec.xz + i_posWorld.xz;
			#else
				float2 snowUV=i_posWorld.xz;
			#endif
			float2 _ddxSnow=ddx(snowUV);
			float2 _ddySnow=ddy(snowUV);
			if (_SnowWorldMapping) {
				uvDet_no_refr=snowUV;
			} else {
				_ddxSnow=_ddxDet;
				_ddySnow=_ddyDet;
			}
		#else
			float2 _ddxSnow=_ddxDet;
			float2 _ddySnow=_ddyDet;
		#endif
		#if defined(DISTANCE_MAP)
			float3 normalWorld = mul(BlendNormals(_norm, NormalInTangentSpace(i_tex, uvDet_no_refr, i_viewDirForParallax, _snow_val_nobump, i_tanToWorld, vertex_color, _ddx, _ddy, _ddxDet, _ddyDet, _ddxSnow, _ddySnow, wetNorm, deepWetFct, /* inout */ _snow_val, /* inout */ dissolveMaskValue, blendFade, i_posWorld)), i_tanToWorld);
			#if defined(_SNOW)
				_snow_val = saturate( _snow_val - (1-normalWorld.y)*_SnowSlopeDamp );
			#endif
		#elif defined(EXTRUSION_MAP)
			// take main normal from _norm that has been set in specialised parallax function (we needed normal there for texturing sidewalls)
			float3 normalWorld = mul(NormalInTangentSpace(_norm, i_tex, uvDet_no_refr, i_viewDirForParallax, _snow_val_nobump, i_tanToWorld, vertex_color, _ddx, _ddy, _ddxDet, _ddyDet, _ddxSnow, _ddySnow, wetNorm, deepWetFct, /* inout */ _snow_val, /* inout */ dissolveMaskValue, blendFade, i_posWorld), i_tanToWorld);
		#else
			#if defined(TRIPLANAR_SELECTIVE)
				float blendFadeWithNormalSharpness = lerp(blendFade, 1-exp2(-9*blendFade), _TriplanarNormalBlendSharpness);
				float3 normInTangentSpace=NormalInTangentSpace(i_tex, uvDet_no_refr, i_viewDirForParallax, _snow_val_nobump, i_tanToWorld, vertex_color, _ddx, _ddy, _ddxDet, _ddyDet, _ddxSnow, _ddySnow, wetNorm, deepWetFct, /* inout */ _snow_val, /* inout */ dissolveMaskValue, blendFade, i_posWorld);
				#if defined(_SNOW) 
					// we don't interpolate normals towards (0,0,1) in case of snow coverage in world space - simply we don't have seams there, so no "blendFade" process is needed out there
					blendFadeWithNormalSharpness = _SnowWorldMapping ? lerp(blendFadeWithNormalSharpness, 1, _snow_val) : blendFadeWithNormalSharpness;
				#endif
				normInTangentSpace = lerp(float3(0,0,1), normInTangentSpace, blendFadeWithNormalSharpness );
				float3 normalWorld = mul(normInTangentSpace, i_tanToWorld);
			#else
				float3 normalWorld = mul(NormalInTangentSpace(i_tex, uvDet_no_refr, i_viewDirForParallax, _snow_val_nobump, i_tanToWorld, vertex_color, _ddx, _ddy, _ddxDet, _ddyDet, _ddxSnow, _ddySnow, wetNorm, deepWetFct, /* inout */ _snow_val, /* inout */ dissolveMaskValue, blendFade, i_posWorld), i_tanToWorld);
			#endif
		#endif
		normalWorld = normalize(normalWorld);
	#else
		// Should get compiled out, isn't being used in the end.
		float3 normalWorld = i_normalWorld;
		#if defined(DISTANCE_MAP)
			normalWorld=mul(_norm, i_tanToWorld);
		#endif
	#endif
	
	
	// alpha
	#if defined(GEOM_BLEND)
		// RTP's geom blend
		float alpha;
		#if defined(BLENDING_HEIGHT)
			float2 globalUV=i_posWorld.xz-_TERRAIN_PosSize.xy;
			globalUV/=_TERRAIN_PosSize.zw;	
			float2 aux=i_posWorld.xz-_TERRAIN_PosSize.xy+_TERRAIN_Tiling.zw;
			aux.xy/=_TERRAIN_Tiling.xy;
			
			float4 terrain_coverage=tex2D(_TERRAIN_Control, globalUV);
			float4 splat_control1=terrain_coverage * tex2D(_TERRAIN_HeightMap, aux.xy) * vertex_color.VERTEX_COLOR_CHANNEL_GEOM_BLEND;
			float4 splat_control2=float4( (actH+0.01) , 0, 0, 0) * (1-vertex_color.VERTEX_COLOR_CHANNEL_GEOM_BLEND);
			
			float blend_coverage=dot(terrain_coverage, 1);
			if (blend_coverage>0.1) {
			
				splat_control1*=splat_control1;
				splat_control1*=splat_control1;
				splat_control2*=splat_control2;
				splat_control2*=splat_control2;
				
				float normalize_sum=dot(splat_control1, float4(1,1,1,1))+dot(splat_control2, float4(1,1,1,1));
				splat_control1 /= normalize_sum;
				splat_control2 /= normalize_sum;		
				
				alpha=dot(splat_control2,1);
				alpha=lerp(1-vertex_color.VERTEX_COLOR_CHANNEL_GEOM_BLEND, alpha, saturate((blend_coverage-0.1)*4) );
			} else {
				alpha=1-vertex_color.VERTEX_COLOR_CHANNEL_GEOM_BLEND;
			}
		#else
			alpha=(1-vertex_color.VERTEX_COLOR_CHANNEL_GEOM_BLEND);
		#endif	
	#else
		// alpha computed regular way (in opposite to geom blend)
		float alpha = Alpha(i_tex, _ddx, _ddy, _ddxDet, _ddyDet, vertex_color); // UBER - ddx, ddy, vertex_color (2 layers)

		#if defined(_ALPHATEST_ON)
				clip(alpha - _Cutoff);
		#endif

		#if defined(_SNOW)
			alpha=lerp(alpha, 1, _snow_val);
		#endif	
		#if defined(_WETNESS)
			alpha=lerp(alpha, 1, Wetness*_WetnessColor.a);
		#endif	
	#endif
	
	FragmentCommonData o = UNITY_SETUP_BRDF_INPUT (i_tex, vertex_color, _ddx, _ddy, _ddxDet, _ddyDet, Wetness, blendFade, diffuseTint, diffuseTint2); // UBER - params added (vertex colors, derivateves)
	o.normalWorld = normalWorld;
	o.eyeVec = eyeVec;
	o.posWorld = i_posWorld;

	#if defined(_ALPHATEST_ON)
		o.additionalEmission+=saturate(_Cutoff - alpha + _CutoffEdgeGlow.a-0.004)*10000*_CutoffEdgeGlow.rgb;
	#endif

//	o.diffColor*=blendFade;
	
	#if defined(_WETNESS)
		float Wetness_with_Const=saturate(Wetness+WetnessConst);
		// wetness specularity (wetness has always "specular" setup)
		o.specColor = lerp(o.specColor, lerp(max(o.specColor, _WetnessSpecGloss.rgb), _WetnessSpecGloss.rgb, _WetnessColor.a), Wetness);
		// wetness darkening (for non emissive water, non opaque water and rough underlying surface)
		o.diffColor *= saturate(1.3-saturate(Wetness_with_Const*_WetnessDarkening*(1-_WetnessEmissiveness)*(1-_WetnessColor.a)*(1-o.smoothness)));
		// wetness gloss
		#if defined(_WETNESS_RIPPLES) || defined(_WETNESS_FULL)
			float wetGloss=saturate(_WetnessSpecGloss.a-rippleMIPsel*_WetnessSpecGloss.a*RippleStrength*_RippleSpecFilter);
		#else
			float wetGloss=_WetnessSpecGloss.a;
		#endif
		
		//wetMask=tex2D(_DetailMask, i_tex.xy*_WetnessUVMult*3).g;
		//wetGloss=0.9+wetMask*wetMask*0.3;
		//wetMask=0.1+tex2D(_DetailMask, i_tex.xy*_WetnessUVMult*5).g*0.5;
		//o.specColor=wetMask.xxx*wetMask.xxx;//lerp(o.specColor, wetMask, Wetness);//wetMask.xxx*o.specColor*10;
		//o.normalWorld=i_normalWorld;
		
		o.smoothness = lerp(o.smoothness, lerp(max(o.smoothness,wetGloss), wetGloss, _WetnessColor.a), Wetness_with_Const); // filtrowanie po rippleMIPsel (usuwa artefakty hi-freq z ripli)
		// wetness emissiveness
		#if defined(_WETNESS_RIPPLES) || defined(_WETNESS_FULL)
			float norm_fluid_val=_WetnessEmissivenessWrap ? (saturate(dot(wetNorm.xy*4, wetNorm.xy*4))*4+0.1) : (wetNorm.x+wetNorm.y+1);
		#else
			float norm_fluid_val=1;
		#endif
		o.additionalEmission += norm_fluid_val*_WetnessColor.rgb*_WetnessEmissiveness*Wetness*deepWetFct; // (8x HDR on emission)
		o.Wetness=Wetness;
	#endif
	
	
	#if defined(_TWO_LAYERS)
		float4 DiffuseScatteringColor=lerp(_DiffuseScatteringColor2, _DiffuseScatteringColor, __VERTEX_COLOR_CHANNEL_LAYER);
	#else
		float4 DiffuseScatteringColor=_DiffuseScatteringColor;
	#endif
	#if defined(_SNOW)
		// conserve energy (snow has specular setup)
		float oneMinusReflectivitySnow;

		float4 SnowSpecGloss = _SnowSpecGlossFromGlobal ? _UBER_GlobalSnowSpecGloss : _SnowSpecGloss;
		float3 diffColorSnow = EnergyConservationBetweenDiffuseAndSpecular( _SnowColorAndCoverage.rgb, SnowSpecGloss.rgb, /* out */ oneMinusReflectivitySnow );

		// simple frost - constant color & diffuse scatter
		float Frost=_FrostFromGlobal ? (1-_UBER_Frost)*_Frost : _Frost;
		#if defined(_WETNESS)
			float frost=Frost*Wetness_with_Const;
		#else
			float frost=Frost;
		#endif
		o.diffColor = lerp(o.diffColor, diffColorSnow, frost*0.05);

		o.specColor = lerp(o.specColor, SnowSpecGloss.rgb, _snow_val);
		o.diffColor = lerp(o.diffColor, diffColorSnow, _snow_val);
		o.smoothness = lerp(o.smoothness, SnowSpecGloss.a, _snow_val);
		o.oneMinusReflectivity=lerp(o.oneMinusReflectivity, oneMinusReflectivitySnow, _snow_val);
		o.snowVal=_snow_val;
		o.dissolveMaskValue=dissolveMaskValue;

		// diffuse scatter
		#if !defined(UNITY_PASS_META)
		float _snow_val_with_frost=max(_snow_val, frost*0.5);
		if (_DiffuseScatter>0) {
		// uniform branching - close to free on modern hardware (anyway - that's what experts like Aras say)
		//#if defined(_DIFFUSE_SCATTER)
			DiffuseScatteringColor=lerp(DiffuseScatteringColor, _SnowDiffuseScatteringColor, _snow_val_with_frost);
			float scatterNdotV=(dot(normalWorld, eyeVec)+lerp(_DiffuseScatteringOffset, _SnowDiffuseScatteringOffset, _snow_val_with_frost));
			float scatter=exp2(-scatterNdotV*scatterNdotV*lerp(_DiffuseScatteringExponent, _SnowDiffuseScatteringExponent, _snow_val_with_frost));
			scatter*=scatter;
			o.diffColor+=lerp(o.diffColor*DiffuseScatteringColor.rgb, DiffuseScatteringColor.rgb, DiffuseScatteringColor.a)*scatter*4;
		//#else
		} else {
			// currently not used part of code (_DIFFUSE_SCATTER is not a feature)
			DiffuseScatteringColor=_SnowDiffuseScatteringColor*_snow_val_with_frost;
			float scatterNdotV=(dot(normalWorld, eyeVec)+_SnowDiffuseScatteringOffset);
			float scatter=exp2(-scatterNdotV*scatterNdotV*_SnowDiffuseScatteringExponent);
			scatter*=scatter;
			o.diffColor+=lerp(o.diffColor*DiffuseScatteringColor.rgb, DiffuseScatteringColor.rgb, DiffuseScatteringColor.a)*scatter*4;
		}
		//#endif
		#endif
	#else
		// diffuse scatter
		#if !defined(UNITY_PASS_META)
		if (_DiffuseScatter>0) {
		// uniform branching - close to free on modern hardware (anyway - that's what experts like Aras say)
		//#if defined(_DIFFUSE_SCATTER)
		#if defined(FAKE_RETROREFLECTION)
			float scatterNdotV = (1 - dot(normalWorld, -eyeVec) + _DiffuseScatteringOffset);
			float scatter = exp2(-scatterNdotV*scatterNdotV*(_DiffuseScatteringExponent - 0.5) * 1000);
			scatter *= scatter;
			o.diffColor += lerp(o.diffColor*DiffuseScatteringColor.rgb, DiffuseScatteringColor.rgb, DiffuseScatteringColor.a)*scatter * 4;
		#else
			float scatterNdotV = (dot(normalWorld, eyeVec) + _DiffuseScatteringOffset);
			float scatter = exp2(-scatterNdotV*scatterNdotV*_DiffuseScatteringExponent);
			scatter *= scatter;
			o.diffColor += lerp(o.diffColor*DiffuseScatteringColor.rgb, DiffuseScatteringColor.rgb, DiffuseScatteringColor.a)*scatter * 4;
		#endif
		//#endif
		}
		#endif
	#endif	
	
	// UBER - SS
	#if defined(_PARALLAX_POM_SHADOWS) || defined(_POM_DISTANCE_MAP_SHADOWS) || defined(_POM_EXTRUSION_MAP_SHADOWS)
	o.rayPos = rayPos;
	o.tanToWorld=i_tanToWorld;
	#endif
	o.texture2ObjectRatio = texture2ObjectRatio;
	#if defined(ZWRITE)
	o.rayLength=rayLength;
	#endif

	// NOTE: shader relies on pre-multiply alpha-blend (_SrcBlend = One, _DstBlend = OneMinusSrcAlpha)
	o.diffColor = PreMultiplyAlpha (o.diffColor, alpha, o.oneMinusReflectivity, /*out*/ o.alpha);

	return o;
}

inline UnityGI FragmentGI (FragmentCommonData s, float occlusion, float4 i_ambientOrLightmapUV, float atten, UnityLight light, bool reflections)
{
	UnityGIInput d;
	d.light = light;
	d.worldPos = s.posWorld;
	d.worldViewDir = -s.eyeVec;
	d.atten = atten;
	#if defined(LIGHTMAP_ON) || defined(DYNAMICLIGHTMAP_ON)
		d.ambient = 0;
		d.lightmapUV = i_ambientOrLightmapUV;
	#else
		d.ambient = i_ambientOrLightmapUV.rgb;
		d.lightmapUV = 0;
	#endif

	d.probeHDR[0] = unity_SpecCube0_HDR;
	d.probeHDR[1] = unity_SpecCube1_HDR;
	#if UNITY_SPECCUBE_BLENDING || UNITY_SPECCUBE_BOX_PROJECTION
	  d.boxMin[0] = unity_SpecCube0_BoxMin; // .w holds lerp value for blending
	#endif
	#if UNITY_SPECCUBE_BOX_PROJECTION
	  d.boxMax[0] = unity_SpecCube0_BoxMax;
	  d.probePosition[0] = unity_SpecCube0_ProbePosition;
	  d.boxMax[1] = unity_SpecCube1_BoxMax;
	  d.boxMin[1] = unity_SpecCube1_BoxMin;
	  d.probePosition[1] = unity_SpecCube1_ProbePosition;
	#endif

	if(reflections)
	{
		Unity_GlossyEnvironmentData g = UnityGlossyEnvironmentSetup(s.smoothness, -s.eyeVec, s.normalWorld, s.specColor);
		// Replace the reflUVW if it has been compute in Vertex shader. Note: the compiler will optimize the calcul in UnityGlossyEnvironmentSetup itself
		#if UNITY_OPTIMIZE_TEXCUBELOD || UNITY_STANDARD_SIMPLE
			g.reflUVW = s.reflUVW;


		#endif

		return UnityGlobalIllumination (d, occlusion, s.normalWorld, g);
	}
	else
	{
		return UnityGlobalIllumination (d, occlusion, s.normalWorld);
	}
}


inline UnityGI FragmentGI(FragmentCommonData s, float occlusion, float4 i_ambientOrLightmapUV, float atten, UnityLight light)
{
	return FragmentGI(s, occlusion, i_ambientOrLightmapUV, atten, light, true);
}


//-------------------------------------------------------------------------------------
float4 OutputForward (float4 output, float alphaFromSurface)
{
	#if defined(_ALPHABLEND_ON) || defined(_ALPHAPREMULTIPLY_ON)
		output.a = alphaFromSurface;
	#else
		UNITY_OPAQUE_ALPHA(output.a);
	#endif
	return output;
}

inline float4 VertexGIForward(VertexInput v, float3 posWorld, float3 normalWorld)
{
	float4 ambientOrLightmapUV = 0;
	// Static lightmaps
#if defined(LIGHTMAP_ON) //|| defined(_3D_PAINT_ACCUMULATOR_)
	ambientOrLightmapUV.xy = v.uv1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
	ambientOrLightmapUV.zw = 0;
	// Sample light probe for Dynamic objects only (no static or dynamic lightmaps)
#elif UNITY_SHOULD_SAMPLE_SH
#if UNITY_SAMPLE_FULL_SH_PER_PIXEL  // TODO: remove this path
	ambientOrLightmapUV.rgb = 0;
#elif (SHADER_TARGET < 30) || UNITY_STANDARD_SIMPLE
	ambientOrLightmapUV.rgb = ShadeSH9(float4(normalWorld, 1.0));
#else
	// Optimization: L2 per-vertex, L0..L1 per-pixel
	ambientOrLightmapUV.rgb = ShadeSH3Order(float4(normalWorld, 1.0));
#endif
	// Add approximated illumination from non-important point lights
#ifdef VERTEXLIGHT_ON
	ambientOrLightmapUV.rgb += Shade4PointLights(
		unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
		unity_LightColor[0].rgb, unity_LightColor[1].rgb, unity_LightColor[2].rgb, unity_LightColor[3].rgb,
		unity_4LightAtten0, posWorld, normalWorld);
#endif
#endif

#ifdef DYNAMICLIGHTMAP_ON
	ambientOrLightmapUV.zw = v.uv2.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
#endif

	return ambientOrLightmapUV;
}


// ------------------------------------------------------------------
//  Base forward pass (directional light, emission, lightmaps, ...)

struct VertexOutputForwardBase
{
	UNITY_POSITION(pos);
	float4 tex							: TEXCOORD0; // normal in triplanar (.w means UV1 - u coord for triplanar - needed for secondary occlusion)
	#if defined(TRIPLANAR_SELECTIVE) && !defined(_TRIPLANAR_WORLD_MAPPING)
		float4 posObject				: TEXCOORD1; // .w means UV1 - v coord for triplanar (needed for secondary occlusion)
	#elif defined(POM) || defined(DISTANCE_MAP) || defined(EXTRUSION_MAP)
		float4 SclCurv					: TEXCOORD1;
	#else
		float4 eyeVec 					: TEXCOORD1; // .w means UV1 - v coord for triplanar (needed for secondary occlusion)
	#endif
	float4 tangentToWorldAndParallax0	: TEXCOORD2;	// [3x3:tangentToWorld | 1x3:viewDirForParallax] - note: tangents+obj scale in triplanar (tangents in world space when mapping in world space)
	float4 tangentToWorldAndParallax1	: TEXCOORD3;	// (array fails in GLSL optimizer)
	float4 tangentToWorldAndParallax2	: TEXCOORD4;
	float4 ambientOrLightmapUV			: TEXCOORD5;	// SH or Lightmap UV
	fixed4 vertex_color					: COLOR0;		// UBER
	UNITY_SHADOW_COORDS(6)
	UNITY_FOG_COORDS(7)

	// next ones would not fit into SM2.0 limits, but they are always for SM3.0+
	#ifdef UNITY_REQUIRE_FRAG_WORLDPOS
		#if defined(ZWRITE)
		float4 posWorld					: TEXCOORD8;
		#else
		float3 posWorld					: TEXCOORD8;
		#endif
	#endif
	#if defined(_REFRACTION) || DECAL_PIERCEABLE
		float4 screenPos				: TEXCOORD9;
	#endif

	UNITY_VERTEX_INPUT_INSTANCE_ID
	UNITY_VERTEX_OUTPUT_STEREO
};

VertexOutputForwardBase vertForwardBase (VertexInput v)
{
	UNITY_SETUP_INSTANCE_ID(v);
	VertexOutputForwardBase o;
	UNITY_INITIALIZE_OUTPUT(VertexOutputForwardBase, o);
	UNITY_TRANSFER_INSTANCE_ID(v, o);
	UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
	
	#if defined(POM) || defined(DISTANCE_MAP) || defined(EXTRUSION_MAP)
		float2 Curv=frac(v.uv3);
		float2 Scl=(v.uv3-Curv)/100; // scale represented with 0.01 resolution (fair enough)
		Scl=Scl*_Tan2ObjectMultOffset.xy+_Tan2ObjectMultOffset.zw;
		//Scl=10;
		#if defined(VERTEX_COLOR_CHANNEL_POMZ)
			v.vertex.xyz+=_POM_ExtrudeVolume ? v.normal.xyz*v.color.VERTEX_COLOR_CHANNEL_POMZ*_Depth*max(Scl.x, Scl.y)/max(_MainTex_ST.x, _MainTex_ST.y) : float3(0,0,0);
			// Curv.x==0 - extruded bottom flag
			v.color.VERTEX_COLOR_CHANNEL_POMZ = Curv.x==0 || (!_POM_ExtrudeVolume) ? v.color.VERTEX_COLOR_CHANNEL_POMZ : 1-v.color.VERTEX_COLOR_CHANNEL_POMZ;
			//Curv=0; // no curvature on extruded volumes (we need bottom flag info in parallax function though - so DON'T zero Curv here !)
			// if we don't handle the volume set the curvature data to desired range
			Curv = _POM_ExtrudeVolume ? Curv : Curv*20-10;
		#else
			Curv=Curv*20-10; // Curv=(Curv-0.5)*10; // we assume curvature won't be higher than +/- 10
		#endif
	#endif

	float4 posWorld = mul(unity_ObjectToWorld, v.vertex);

	#ifdef UNITY_REQUIRE_FRAG_WORLDPOS
		o.posWorld.xyz = posWorld.xyz;
		#if defined(ZWRITE)
			COMPUTE_EYEDEPTH(o.posWorld.w);
		#endif
	#endif

	o.vertex_color = v.color; // UBER
	o.pos = UnityObjectToClipPos(v.vertex);

	#if defined(TRIPLANAR_SELECTIVE) && !defined(_TRIPLANAR_WORLD_MAPPING)
		//o.posObject set below
	#elif defined(POM) || defined(DISTANCE_MAP) || defined(EXTRUSION_MAP)
		o.SclCurv=float4(float2(1.0,1.0)/Scl, Curv);
	#else
		o.eyeVec.xyz = posWorld.xyz - _WorldSpaceCameraPos;
		#if defined(TRIPLANAR_SELECTIVE)
			// world mapping
			o.eyeVec.w = v.uv1.y;
		#endif
	#endif

	#if defined(TRIPLANAR_SELECTIVE)
		#if defined(_TRIPLANAR_WORLD_MAPPING)
			float3 normalWorld = UnityObjectToWorldNormal(v.normal);
			SetupUBER_VertexData_TriplanarWorld(normalWorld, /* inout */ o.tangentToWorldAndParallax0, /* inout */ o.tangentToWorldAndParallax1, /* inout */ o.tangentToWorldAndParallax2);
		#else
			float scaleX, scaleY, scaleZ;
			SetupUBER_VertexData_TriplanarLocal(v.normal, /* inout */ o.tangentToWorldAndParallax0, /* inout */ o.tangentToWorldAndParallax1, /* inout */ o.tangentToWorldAndParallax2, /* out */ scaleX, /* out */ scaleY, /* out */ scaleZ);
			float3 normalWorld = UnityObjectToWorldNormal(v.normal);
			o.posObject.xyz = v.vertex.xyz;
			o.posObject.w = v.uv1.y; // pack it here
		#endif		
	#elif defined(_TANGENT_TO_WORLD)
		float3x3 tangentToWorld;

		// we need to go from tangent to world space for zwrite and parallaxed snow (actually when snow is mapped in worldspace)
		#if defined(RAYLENGTH_AVAILABLE)
			float3 normalWorld = mul((float3x3)unity_ObjectToWorld, v.normal.xyz);
			float3 tangentWorld = mul((float3x3)unity_ObjectToWorld, v.tangent.xyz);
			float3 binormalWorld = mul((float3x3)unity_ObjectToWorld, cross(v.normal.xyz, v.tangent.xyz)*v.tangent.w);
			#ifdef SHADER_TARGET_GLSL
			binormalWorld*=0.9999; // dummy op to cheat HLSL2GLSL optimizer to not be so smart (and buggy) here... It probably tries to make some fancy matrix by matrix calculation
			#endif
			// not normalized basis (we need it for texture 2 worldspace ratio calculations)
			tangentToWorld=float3x3(tangentWorld, binormalWorld, normalWorld);
			normalWorld = normalize(normalWorld); // we need it below for lighting
		#else
			float3 normalWorld = UnityObjectToWorldNormal(v.normal);
			float4 tangentWorld = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);
			tangentToWorld = CreateTangentToWorldPerVertex(normalWorld, tangentWorld.xyz, v.tangent.w);
		#endif

		o.tangentToWorldAndParallax0.xyz = tangentToWorld[0];
		o.tangentToWorldAndParallax1.xyz = tangentToWorld[1];
		o.tangentToWorldAndParallax2.xyz = tangentToWorld[2];
	#else
		float3 normalWorld = UnityObjectToWorldNormal(v.normal);
		o.tangentToWorldAndParallax0.xyz = 0;
		o.tangentToWorldAndParallax1.xyz = 0;
		o.tangentToWorldAndParallax2.xyz = normalWorld;
	#endif
	//We need this for shadow receving
	UNITY_TRANSFER_SHADOW(o, v.uv1);
	
	o.ambientOrLightmapUV = VertexGIForward(v, posWorld, normalWorld);

	#if defined(TRIPLANAR_SELECTIVE)
		#if defined(_TRIPLANAR_WORLD_MAPPING)
			// .w component not used
		#else
			o.tangentToWorldAndParallax0.w=scaleX;
			o.tangentToWorldAndParallax1.w=scaleY;
			o.tangentToWorldAndParallax2.w=scaleZ;
		#endif
	#elif defined(_PARALLAXMAP) || defined(_PARALLAXMAP_2MAPS) || defined(POM) || defined(DISTANCE_MAP) || defined(EXTRUSION_MAP)
		#if ((defined(POM)) && defined(SILHOUETTE_CURVATURE_MAPPED))
			float3 viewDirForParallax = ObjSpaceViewDir(v.vertex);
		#else
			// vertex normal, tangent are not guaranteed to be normalized (!)
			// try - 2 simple planes on the scene using the same material, anchored and parent has decreased scale, Unity makes kind of batch (vertices seems to be transformed to world space) ? Anyway mesh tangents, normals get scaled, too and makes total mess with TBN matrices (view direction...)
			v.normal=normalize(v.normal);
			v.tangent.xyz=normalize(v.tangent.xyz);
			float3 binormal = cross( v.normal, v.tangent.xyz ) * v.tangent.w;
			float3x3 rotation = float3x3( v.tangent.xyz, binormal, v.normal );
			float3 viewDirForParallax = mul(rotation, ObjSpaceViewDir(v.vertex));
		#endif
		o.tangentToWorldAndParallax0.w = viewDirForParallax.x;
		o.tangentToWorldAndParallax1.w = viewDirForParallax.y;
		o.tangentToWorldAndParallax2.w = viewDirForParallax.z;
	#endif
	#if defined(_REFRACTION) || DECAL_PIERCEABLE
		o.screenPos = ComputeScreenPos (o.pos);
		COMPUTE_EYEDEPTH(o.screenPos.z); // used for pierceables
	#endif
	
	#if defined(TRIPLANAR_SELECTIVE)
		#if defined(_TRIPLANAR_WORLD_MAPPING)
			o.tex = float4(normalWorld, v.uv1.x); // pack UV1 here
		#else
			o.tex = float4(v.normal, v.uv1.x); // pack UV1 here
		#endif
	#else
		o.tex = TexCoordsNoTransform(v);
	#endif
	
	UNITY_TRANSFER_FOG(o,o.pos);
	return o;
}

#if DECAL_PIERCEABLE
	// piercing depth mask buffer (for pierceable deferred) or mask additive forward decals
	sampler2D_float _PiercingBuffer;
	// depth on which decal has been placed
	sampler2D_float _PiercingDepthBuffer;
	// uniform bool to save keyword, we need also to #define DECAL_PIERCEABLE to get this part of code actually compiled
	bool _Pierceable;
	float _PiercingThreshold; // Piercing threshold (forward)
#endif


/* _Paint3DAccumulator_ */
void fragPaint3DAccumulator (VertexOutputForwardBase i, out float4 outColor : SV_Target
#if defined(_2SIDED)
,float facing : VFACE
#endif
//#if defined(ZWRITE)
//,out float outDepth : DEPTH_SEMANTIC
//#endif
)
{
	/*
	struct VertexOutputForwardBase
	{
		UNITY_POSITION(pos);
		float4 tex							: TEXCOORD0; // normal in triplanar (.w means UV1 - u coord for triplanar - needed for secondary occlusion)
		#if defined(TRIPLANAR_SELECTIVE) && !defined(_TRIPLANAR_WORLD_MAPPING)
			float4 posObject				: TEXCOORD1; // .w means UV1 - v coord for triplanar (needed for secondary occlusion)
		#elif defined(POM) || defined(DISTANCE_MAP) || defined(EXTRUSION_MAP)
			float4 SclCurv					: TEXCOORD1;
		#else
			float4 eyeVec 					: TEXCOORD1; // .w means UV1 - v coord for triplanar (needed for secondary occlusion)
		#endif
		float4 tangentToWorldAndParallax0	: TEXCOORD2;	// [3x3:tangentToWorld | 1x3:viewDirForParallax] - note: tangents+obj scale in triplanar (tangents in world space when mapping in world space)
		float4 tangentToWorldAndParallax1	: TEXCOORD3;	// (array fails in GLSL optimizer)
		float4 tangentToWorldAndParallax2	: TEXCOORD4;
		float4 ambientOrLightmapUV			: TEXCOORD5;	// SH or Lightmap UV
		fixed4 vertex_color					: COLOR0;		// UBER
		UNITY_SHADOW_COORDS(6)
		UNITY_FOG_COORDS(7)

		// next ones would not fit into SM2.0 limits, but they are always for SM3.0+
		#ifdef UNITY_REQUIRE_FRAG_WORLDPOS
			#if defined(ZWRITE)
			float4 posWorld					: TEXCOORD8;
			#else
			float3 posWorld					: TEXCOORD8;
			#endif
		#endif
		#if defined(_REFRACTION) || DECAL_PIERCEABLE
			float4 screenPos				: TEXCOORD9;
		#endif

		UNITY_VERTEX_INPUT_INSTANCE_ID
		UNITY_VERTEX_OUTPUT_STEREO
	};
	*/
	/*
	struct v2f_P3DA
	{
		float2 uv : TEXCOORD0;
		float3 worldPos : TEXCOORD1;
		float4 vertex : SV_POSITION;
		#ifdef _CUSTOM_VERTEX_DISPLACEMENT_
		float3 normal : TEXCOORD2;
		#endif
	};
	*/
	v2f_P3DA iP3DA;
	iP3DA.uv0 = i.tex.xy;
	iP3DA.uv1 = i.ambientOrLightmapUV.xy;
	#ifdef UNITY_REQUIRE_FRAG_WORLDPOS
	iP3DA.worldPos = i.posWorld;
	#endif
	iP3DA.vertex = i.pos;
	#ifdef _CUSTOM_VERTEX_DISPLACEMENT_
	iP3DA.normal = i.tex.rgb;
	#endif
	outColor = Paint3DAccumulatorFragmentLogic_P0(iP3DA);	

}


	

void fragForwardBase (VertexOutputForwardBase i, out float4 outCol : SV_Target
#if defined(_2SIDED)
,float facing : VFACE
#endif
#if defined(ZWRITE)
,out float outDepth : DEPTH_SEMANTIC
#endif
)
{
	UNITY_APPLY_DITHER_CROSSFADE(i.pos.xy);
	UNITY_SETUP_INSTANCE_ID(i);

	#if defined(_2SIDED)
		#if UNITY_VFACE_FLIPPED
			facing = -facing;
		#endif
		#if UNITY_VFACE_AFFECTED_BY_PROJECTION
			facing *= _ProjectionParams.x; // take possible upside down rendering into account
		#endif	
		#if defined(TRIPLANAR_SELECTIVE)
			i.tex.xyz *= facing>0 ? 1 : -1;
		#else
			i.tangentToWorldAndParallax2 *= facing>0 ? 1 : -1;
		#endif
	#endif
	
	#if defined(TRIPLANAR_SELECTIVE)
		// unpack UV1
		#if defined(_TRIPLANAR_WORLD_MAPPING)
			float2 secUV=float2(i.tex.w, i.eyeVec.w);
		#else
			float2 secUV=float2(i.tex.w, i.posObject.w);
		#endif		
	#endif

	// ------
	float actH;
	float4 SclCurv;
	float3 eyeVec;
	
	float3 tangentBasisScaled;
	
	float2 _ddx;
	float2 _ddy;
	float2 _ddxDet;
	float2 _ddyDet;
	float blendFade;
	
	float3 i_viewDirForParallax;
	float3x3 _TBN;
	float3 worldNormal;
	
	float4 texcoordsNoTransform;
	
	// void	SetupUBER(float4 i_SclCurv, float3 i_eyeVec, float3 i_posWorld, float3 i_posObject, inout float4 i_tex, inout float4 i_tangentToWorldAndParallax0, inout float4 i_tangentToWorldAndParallax1, inout float4 i_tangentToWorldAndParallax2, inout fixed4 vertex_color, out float actH, out float4 SclCurv, out float3 eyeVec, out float3 tangentBasisScaled, out float2 _ddx, out float2 _ddy, out float2 _ddxDet, out float2 _ddyDet, out float blendFade, out float3 i_viewDirForParallax, out float3x3 _TBN, out float3 worldNormal) {
	#if defined(TRIPLANAR_SELECTIVE) && !defined(_TRIPLANAR_WORLD_MAPPING)
		SetupUBER(float4(0,0,0,0), float3(0,0,0), IN_WORLDPOS(i), i.posObject.xyz, /* inout */ i.tex, /* inout */ i.tangentToWorldAndParallax0, /* inout */ i.tangentToWorldAndParallax1, /* inout */ i.tangentToWorldAndParallax2, /* inout */ i.vertex_color, /* out */ actH, /* out */ SclCurv, /* out */ eyeVec, /* out */ tangentBasisScaled, /* out */ _ddx, /* out */ _ddy, /* out */ _ddxDet, /* out */ _ddyDet, /* out */ blendFade, /* out */ i_viewDirForParallax, /* out */ _TBN, /* out */ worldNormal, /* out */ texcoordsNoTransform);
	#elif defined(POM) || defined(DISTANCE_MAP) || defined(EXTRUSION_MAP)
		SetupUBER(i.SclCurv, float3(0,0,0), IN_WORLDPOS(i), float3(0,0,0), /* inout */ i.tex, /* inout */ i.tangentToWorldAndParallax0, /* inout */ i.tangentToWorldAndParallax1, /* inout */ i.tangentToWorldAndParallax2, /* inout */ i.vertex_color, /* out */ actH, /* out */ SclCurv, /* out */ eyeVec, /* out */ tangentBasisScaled, /* out */ _ddx, /* out */ _ddy, /* out */ _ddxDet, /* out */ _ddyDet, /* out */ blendFade, /* out */ i_viewDirForParallax, /* out */ _TBN, /* out */ worldNormal, /* out */ texcoordsNoTransform);
	#else
		SetupUBER(float4(0,0,0,0), i.eyeVec.xyz, IN_WORLDPOS(i), float3(0,0,0), /* inout */ i.tex, /* inout */ i.tangentToWorldAndParallax0, /* inout */ i.tangentToWorldAndParallax1, /* inout */ i.tangentToWorldAndParallax2, /* inout */ i.vertex_color, /* out */ actH, /* out */ SclCurv, /* out */ eyeVec, /* out */ tangentBasisScaled, /* out */ _ddx, /* out */ _ddy, /* out */ _ddxDet, /* out */ _ddyDet, /* out */ blendFade, /* out */ i_viewDirForParallax, /* out */ _TBN, /* out */ worldNormal, /* out */ texcoordsNoTransform);
	#endif
	// ------	

//#if defined(VERTEX_COLOR_RGB_TO_ALBEDO_INDEXED)
//		float3 diffuseTint = i.diffuseTint;
//#else
		float3 diffuseTint = float3(0.5, 0.5, 0.5); // n/u
		float3 diffuseTint2 = float3(0.5, 0.5, 0.5);
//#endif

	FRAGMENT_SETUP(s)	
	#ifdef _3D_PAINT_ACCUMULATOR_
		v2f_P3DA iP3DA;
		iP3DA.uv0 = i.tex.xy/_MainTex_ST.xy - _MainTex_ST.zw;
		iP3DA.uv1 = i.ambientOrLightmapUV.xy;
		iP3DA.worldPos = i.posWorld;
		iP3DA.vertex = i.pos;
		#ifdef _CUSTOM_VERTEX_DISPLACEMENT_
			iP3DA.normal = i.tex.rgb;
		#endif
		// tried to assigned the RT directly to the albedo of uber every frame but was black and transparent
		float4 paintColor = Paint3DAccumulatorFragmentLogic_P1(iP3DA);
		float3 paintColorrgbSmall = paintColor.rgb*0.05;
		s.diffColor.rgb += paintColor.rgb*0.95;
		s.alpha *= paintColor.a;
		//s.alpha = 0; // EVEN with this to 0, it draws the diffColor.
		//s.alpha = 1;
		//outCol.a = 0;
	#endif

	
	UnityLight mainLight = MainLight ();
	UNITY_LIGHT_ATTENUATION(atten, i, s.posWorld, shadow_atten); // atten is not used (for main directional light shadow_atten is the only atten present)
	
	float2 occ=Occlusion(i.tex, _ddx, _ddy, _ddxDet, _ddyDet, i.vertex_color); // y - translucency/glitter
	float occlusion = occ.x;
	#if defined(OCCLUSION_VERTEX_COLOR_CHANNEL)
		occlusion*=i.vertex_color.OCCLUSION_VERTEX_COLOR_CHANNEL;
	#endif
	#if defined(_TWO_LAYERS)
		occlusion = LerpOneTo(occlusion, lerp(_OcclusionStrength2, _OcclusionStrength, i.__VERTEX_COLOR_CHANNEL_LAYER));
	#else
		occlusion = LerpOneTo(occlusion, _OcclusionStrength);
	#endif

	#if defined(_TRANSLUCENCY)
		float translucency_thickness_fromOccMap = 1;
	#endif
	if (_Occlusion_from_albedo_alpha) { // uniform bool (float for sake of d3d9 compatibility)
		// possible 2ndary occlusion
		// primary occlusion from diffuse A, secondary from _OcclusionMap
		#if defined(TRIPLANAR_SELECTIVE)
			// already unpacked secUV
		#else
			#if defined(SECONDARY_OCCLUSION_PARALLAXED)
				float2 secUV=((i.tex.xy-_MainTex_ST.zw)/_MainTex_ST.xy - texcoordsNoTransform.xy) + texcoordsNoTransform.zw;
			#else
				float2 secUV=texcoordsNoTransform.zw; // actually we don't need parallax applied as we assume secondary occlusion is low freq maybe
			#endif
		#endif
		secUV = _UVSecOcclusionLightmapPacked==1 ? (secUV * unity_LightmapST.xy + unity_LightmapST.zw) : secUV;
		float4 occVal = tex2Dp(_OcclusionMap, secUV,  ddx(secUV),  ddy(secUV));
		float2 occ2 = float2(occVal.AMBIENT_OCCLUSION_CHANNEL, occVal.AUX_OCCLUSION_CHANNEL);
		// UV0 / UV1 occlusion switch
		occlusion *= (_UVSecOcclusion==0) ? 1 : lerp(1, occ2.x, _SecOcclusionStrength);
		#if defined(_TRANSLUCENCY)
			// translucency mask from UV1
			translucency_thickness_fromOccMap = occ2.y;
		#endif
	}

	#if defined(_SNOW)
		occlusion*=lerp(1, s.dissolveMaskValue, s.snowVal*_SnowDissolveMaskOcclusion);
	#endif
	#if defined(TRIPLANAR_SELECTIVE)
		occlusion*=lerp(1, blendFade, _TriplanarBlendAmbientOcclusion);
	#endif
	#if defined(_SNOW)
		occlusion=lerp(occlusion, 1, saturate(s.snowVal*_SnowDeepSmoothen*0.15));
	#endif

	#if defined(_TRANSLUCENCY)
		// UV0 / UV1 occlusion switch	
		float translucency_thickness = _UVSecOcclusion==0 ? occ.y : translucency_thickness_fromOccMap;
	#endif	

	#if defined(_REFRACTION) || DECAL_PIERCEABLE
		float2 screenUV = (i.screenPos.xy / i.screenPos.w);
		#if !defined(SHADER_API_OPENGL) && !defined(SHADER_API_GLCORE) && !defined(SHADER_API_GLES3)
			screenUV.y = _ProjectionParams.x>0 ? 1 - screenUV.y : screenUV.y;
		#endif
	#endif

	// translucency
	#if defined(_TRANSLUCENCY)
		float3 TL=Translucency(s, mainLight, translucency_thickness, i.vertex_color);
		s.diffColor*=saturate(1-max(max(TL.r, TL.g), TL.b)*TRANSLUCENCY_SUPPRESS_DIFFUSECOLOR);
		shadow_atten =lerp(shadow_atten, 1, saturate( dot(TL,1)*_TranslucencySuppressRealtimeShadows ) );
	#endif	
	
	UnityGI gi = FragmentGI(s, occlusion, i.ambientOrLightmapUV, shadow_atten, mainLight);

	#if defined(_PARALLAX_POM_SHADOWS) || defined(_POM_DISTANCE_MAP_SHADOWS) || defined(_POM_EXTRUSION_MAP_SHADOWS)
		#if defined(_SNOW) && !defined(_POM_DISTANCE_MAP_SHADOWS) && !defined(_POM_EXTRUSION_MAP_SHADOWS)
			bool SS_flag = (saturate(s.snowVal*_SnowDeepSmoothen)<0.98);
		#else
			bool SS_flag = true;
		#endif
		if (SS_flag) {
			float3 lightDirInTanSpace=mul(s.tanToWorld, gi.light.dir);  // named tanToworld but this mul() actually works the opposite (as I swapped params in mul)
			#if defined(_SNOW) && !defined(_POM_DISTANCE_MAP_SHADOWS) && !defined(_POM_EXTRUSION_MAP_SHADOWS)
				gi.light.color *= SelfShadows(s.rayPos, s.texture2ObjectRatio, lightDirInTanSpace, s.snowVal);
			#else
				#if defined(_POM_DISTANCE_MAP_SHADOWS) || defined(_POM_EXTRUSION_MAP_SHADOWS)
					gi.light.color *= lerp( SelfShadows(s.rayPos, s.texture2ObjectRatio, lightDirInTanSpace, 0), 1, saturate( distance(i.posWorld, _WorldSpaceCameraPos) / _DepthReductionDistance ) );
				#else
					gi.light.color *= SelfShadows(s.rayPos, s.texture2ObjectRatio, lightDirInTanSpace, 0);
				#endif
			#endif
		}
	#endif
	
	#if defined(_GLITTER)
		Glitter(/* inout */ s, i.tex.zw, _ddxDet, _ddyDet, i.posWorld.xyz, i.vertex_color, lerp(1, occ.y, _GlitterMask));
	#endif	

	float4 c = UNITY_BRDF_PBS (s.diffColor, s.specColor, s.oneMinusReflectivity, s.smoothness, s.normalWorld, -s.eyeVec, gi.light, gi.indirect);

	#if defined(_TRANSLUCENCY)
		c.rgb += TL*gi.light.color;
	#endif	

	#if defined(_SNOW)
		float snowBlur=_SnowDeepSmoothen*4*s.snowVal; // currently not used
		float3 snowEmissionDamp=LerpWhiteTo(_SnowEmissionTransparency, s.snowVal);
	#else
		float snowBlur=0; // not used
		float3 snowEmissionDamp=1;
	#endif

	#if defined(EMISSION_AT_THE_OTHER_SIDE)
		snowEmissionDamp *= saturate(dot(-i.tangentToWorldAndParallax2, DeferredLightDir(i.posWorld.xyz))*4.);
	#endif

	c.rgb += Emission(i.tex.xyzw, i.vertex_color, _ddx, _ddy, snowBlur)*snowEmissionDamp; // UBER - 4 components (main uv, detail uv) + vertex color (for masking), under snow blurring
	c.rgb += s.additionalEmission*snowEmissionDamp; // UBER - detail/wet emission

	UNITY_APPLY_FOG(i.fogCoord, c.rgb);

	#if DECAL_PIERCEABLE
		if (_Pierceable == true) {
			float2 screenUV = (i.screenPos.xy / i.screenPos.w);
			#if !defined(SHADER_API_OPENGL) && !defined(SHADER_API_GLCORE) && !defined(SHADER_API_GLES3)
				screenUV.y = _ProjectionParams.x>0 ? 1 - screenUV.y : screenUV.y;
			#endif

			//float piercingDepthBuffer = tex2D(_PiercingDepthBuffer, screenUV).r; // linear depth stored in Rfloat buffer (depth of surface where piercing decal is placed with small offset to prevent fighting)
			//float ldepth = i.screenPos.z; // linear eye depth passed from vertex program
			//float depthFade = 1 - saturate(abs(piercingDepthBuffer - ldepth) * 16);

			float2 piercingBuffer = tex2D(_PiercingBuffer, screenUV).rg;
			float forwardDecalAlpha = piercingBuffer.g * 4;
			float piercingValue = saturate((_PiercingThreshold - piercingBuffer.r) * 20);
			forwardDecalAlpha = 1 - saturate(forwardDecalAlpha); 
			forwardDecalAlpha *= piercingValue;
			s.alpha *= forwardDecalAlpha; // fadeout pixels written by piercing decal
			//s.alpha *= piercingValue; // fadeout pixels written by piercing decal
			c.rgb *= forwardDecalAlpha; // fadeout specular highlights
			//c.rgb *= piercingValue; // remove completely the hole
		}
	#endif

	#if defined(LOD_FADE_CROSSFADE) && (defined(_ALPHABLEND_ON) || defined(_ALPHAPREMULTIPLY_ON))
		s.alpha *= unity_LODFade.x;
	#endif

	#if defined(_REFRACTION)
		float3 worldViewDir = s.posWorld - _WorldSpaceCameraPos.xyz;
		worldViewDir=normalize(worldViewDir);
		//UNITY_MATRIX_V[1].xyz // cam up
		//UNITY_MATRIX_V[0].xyz // cam right
		float NdotV=dot(_RefractionBumpScale*s.normalWorld+_TBN[2], s.eyeVec);
		//float2 offset=_Refraction*float2(dot(s.normalWorld, UNITY_MATRIX_V[0].xyz*dot(worldViewDir,UNITY_MATRIX_V[2].xyz)), dot(s.normalWorld, UNITY_MATRIX_V[1].xyz*dot(worldViewDir,UNITY_MATRIX_V[2].xyz)))*(NdotV*NdotV);
		float2 offset=_Refraction*float2(dot(_TBN[2], UNITY_MATRIX_V[0].xyz*dot(worldViewDir,UNITY_MATRIX_V[2].xyz)), dot(_TBN[2], UNITY_MATRIX_V[1].xyz*dot(_TBN[2],UNITY_MATRIX_V[2].xyz)))*(NdotV*NdotV);
		float2 dampUV=abs(screenUV*2-1);
		float borderDamp=saturate(1 - max ( (dampUV.x-0.9)/(1-0.9) , (dampUV.y-0.85)/(1-0.85) ));
		offset*=borderDamp;
		float3 centerCol=tex2D(_GrabTexture, screenUV+offset).rgb;
		#if defined(_CHROMATIC_ABERRATION) 
			float abberrationG=1-_RefractionChromaticAberration;
			float abberrationB=1+_RefractionChromaticAberration;
			float _R=centerCol.r;
			float3 sceneColor = float3(_R, tex2D(_GrabTexture, screenUV+offset*lerp(abberrationG, 1, NdotV)).g, tex2D(_GrabTexture, screenUV+offset*lerp(abberrationB, 1, NdotV)).b);
		#else
			float3 sceneColor = centerCol;
		#endif
		c.rgb+=sceneColor*(1-s.alpha);
		outCol=float4(c.rgb, 1);
	#else
		outCol=OutputForward (c, s.alpha);
	#endif
	
	#if defined(ZWRITE)
		//float depthWithOffset = i.posWorld.w+s.rayLength;
		float depthWithOffset = i.posWorld.w*(1+s.rayLength/distance(i.posWorld.xyz, _WorldSpaceCameraPos)); // Z-DEPTH perspective correction
		outDepth = (1.0 - depthWithOffset * _ZBufferParams.w) / (depthWithOffset * _ZBufferParams.z);
	#endif
	
	
	#if defined(DISTANCE_MAP)
		//outCol.rgb += i_viewDirForParallax.xyz;// i.vertex_color.a;//s.rayPos.z;
		//outCol.rgba = 1;// s.normalWorld*0.5 + 0.5;
	#endif
	
	#ifdef _3D_PAINT_ACCUMULATOR_
		outCol.rgb += paintColorrgbSmall;
	#endif

//	UNITY_MATRIX_V[3].xyz;//
//Camera position = _WorldSpaceCameraPos = mul(UNITY_MATRIX_V,float4(0,0,0,1)).xyz;
	
//	outCol.rgb=s.normalWorld;

}

// ------------------------------------------------------------------
//  Additive forward pass (one light per pass)
struct VertexOutputForwardAdd
{
	UNITY_POSITION(pos);
	float4 tex							: TEXCOORD0; // normal in triplanar (.w means UV1 - u coord for triplanar - needed for secondary occlusion)
	#if defined(TRIPLANAR_SELECTIVE) && !defined(_TRIPLANAR_WORLD_MAPPING)
		float4 posObject				: TEXCOORD1; // .w means UV1 - v coord for triplanar (needed for secondary occlusion)
	#elif defined(POM) || defined(DISTANCE_MAP) || defined(EXTRUSION_MAP)
		float4 SclCurv					: TEXCOORD1;
	#else
		float4 eyeVec 					: TEXCOORD1; // .w means UV1 - v coord for triplanar (needed for secondary occlusion)
	#endif
	float4 tangentToWorldAndParallax0	: TEXCOORD2;	// [3x3:tangentToWorld | 1x3:viewDirForParallax] - note: tangents+obj scale in triplanar (tangents in world space when mapping in world space)
	float4 tangentToWorldAndParallax1	: TEXCOORD3;
	float4 tangentToWorldAndParallax2	: TEXCOORD4;
	fixed4 vertex_color					: COLOR0;
	#if defined(ZWRITE)
		float4 posWorld					: TEXCOORD5;
	#else
		float3 posWorld					: TEXCOORD5;
	#endif
	UNITY_SHADOW_COORDS(6)
	UNITY_FOG_COORDS(7)


	#if DECAL_PIERCEABLE
		float4 screenPos				: TEXCOORD8;
	#endif

	UNITY_VERTEX_OUTPUT_STEREO
};

VertexOutputForwardAdd vertForwardAdd (VertexInput v)
{
	UNITY_SETUP_INSTANCE_ID(v);
	VertexOutputForwardAdd o;
	UNITY_INITIALIZE_OUTPUT(VertexOutputForwardAdd, o);
	UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

	#if defined(POM) || defined(DISTANCE_MAP) || defined(EXTRUSION_MAP)
		float2 Curv=frac(v.uv3);
		float2 Scl=(v.uv3-Curv)/100; // scale represented with 0.01 resolution (fair enough)
		Scl=Scl*_Tan2ObjectMultOffset.xy+_Tan2ObjectMultOffset.zw;
		#if defined(VERTEX_COLOR_CHANNEL_POMZ)
			v.vertex.xyz+=_POM_ExtrudeVolume ? v.normal.xyz*v.color.VERTEX_COLOR_CHANNEL_POMZ*_Depth*max(Scl.x, Scl.y)/max(_MainTex_ST.x, _MainTex_ST.y) : float3(0,0,0);
			// Curv.x==0 - extruded bottom flag
			v.color.VERTEX_COLOR_CHANNEL_POMZ = Curv.x==0 || (!_POM_ExtrudeVolume) ? v.color.VERTEX_COLOR_CHANNEL_POMZ : 1-v.color.VERTEX_COLOR_CHANNEL_POMZ;
			//Curv=0; // no curvature on extruded volumes (we need bottom flag info in parallax function though - so DON'T zero Curv here !)
			// if we don't handle the volume set the curvature data to desired range
			Curv = _POM_ExtrudeVolume ? Curv : Curv*20-10;
		#else
			Curv=Curv*20-10; // Curv=(Curv-0.5)*10; // we assume curvature won't be higher than +/- 10
		#endif
	#endif

	float4 posWorld = mul(unity_ObjectToWorld, v.vertex);
	o.posWorld.xyz = posWorld.xyz;
	#if defined(ZWRITE)
		COMPUTE_EYEDEPTH(o.posWorld.w);
	#endif		
	o.vertex_color = v.color;
	#if defined(UNITY_SUPPORT_INSTANCING) && defined(INSTANCING_ON)
		o.pos = mul(UNITY_MATRIX_M, v.vertex);
		o.pos = mul(UNITY_MATRIX_VP, o.pos);
	#else
		o.pos = UnityObjectToClipPos(v.vertex);
	#endif

	#if DECAL_PIERCEABLE
		o.screenPos = ComputeScreenPos (o.pos);
		COMPUTE_EYEDEPTH(o.screenPos.z); // used for pierceables
	#endif
	
	#if defined(TRIPLANAR_SELECTIVE) && !defined(_TRIPLANAR_WORLD_MAPPING)
		//o.posObject set below
	#elif defined(POM) || defined(DISTANCE_MAP) || defined(EXTRUSION_MAP)
		o.SclCurv=float4(float2(1.0,1.0)/Scl, Curv);
	#else
		o.eyeVec.xyz = posWorld.xyz - _WorldSpaceCameraPos;
		#if defined(TRIPLANAR_SELECTIVE)
			// world mapping
			o.eyeVec.w = v.uv1.y;
		#endif
	#endif
	
	#if defined(TRIPLANAR_SELECTIVE)
		#if defined(_TRIPLANAR_WORLD_MAPPING)
			float3 normalWorld = UnityObjectToWorldNormal(v.normal);
			SetupUBER_VertexData_TriplanarWorld(normalWorld, /* inout */ o.tangentToWorldAndParallax0, /* inout */ o.tangentToWorldAndParallax1, /* inout */ o.tangentToWorldAndParallax2);
		#else
			float scaleX, scaleY, scaleZ;
			SetupUBER_VertexData_TriplanarLocal(v.normal, /* inout */ o.tangentToWorldAndParallax0, /* inout */ o.tangentToWorldAndParallax1, /* inout */ o.tangentToWorldAndParallax2, /* out */ scaleX, /* out */ scaleY, /* out */ scaleZ);
			float3 normalWorld = UnityObjectToWorldNormal(v.normal);
			o.posObject.xyz = v.vertex.xyz;
			o.posObject.w = v.uv1.y; // pack it here
		#endif		
	#elif defined(_TANGENT_TO_WORLD)
		float3x3 tangentToWorld;
		
		// we need to go from tangent to world space for zwrite and parallaxed snow (actually when snow is mapped in worldspace)
		#if defined(RAYLENGTH_AVAILABLE)
			float3 normalWorld = mul((float3x3)unity_ObjectToWorld, v.normal.xyz);
			float3 tangentWorld = mul((float3x3)unity_ObjectToWorld, v.tangent.xyz);
			float3 binormalWorld = mul((float3x3)unity_ObjectToWorld, cross(v.normal.xyz, v.tangent.xyz)*v.tangent.w);
			#ifdef SHADER_TARGET_GLSL
			binormalWorld*=0.9999; // dummy op to cheat HLSL2GLSL optimizer to not be so smart (and buggy) here... It probably tries to make some fancy matrix by matrix calculation
			#endif
			// not normalized basis (we need it for texture 2 worldspace ratio calculations)
			tangentToWorld=float3x3(tangentWorld, binormalWorld, normalWorld);
			normalWorld = normalize(normalWorld); // we need it below for lighting
		#else
			float3 normalWorld = UnityObjectToWorldNormal(v.normal);
			float4 tangentWorld = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);
			tangentToWorld = CreateTangentToWorldPerVertex(normalWorld, tangentWorld.xyz, v.tangent.w);
		#endif

		o.tangentToWorldAndParallax0.xyz = tangentToWorld[0];
		o.tangentToWorldAndParallax1.xyz = tangentToWorld[1];
		o.tangentToWorldAndParallax2.xyz = tangentToWorld[2];
	#else
		float3 normalWorld = UnityObjectToWorldNormal(v.normal);
		o.tangentToWorldAndParallax0.xyz = 0;
		o.tangentToWorldAndParallax1.xyz = 0;
		o.tangentToWorldAndParallax2.xyz = normalWorld;
	#endif
	//We need this for shadow receving
	UNITY_TRANSFER_SHADOW(o, v.uv1);

	#if defined(TRIPLANAR_SELECTIVE)
		#if defined(_TRIPLANAR_WORLD_MAPPING)
			// .w component not used
		#else
			o.tangentToWorldAndParallax0.w=scaleX;
			o.tangentToWorldAndParallax1.w=scaleY;
			o.tangentToWorldAndParallax2.w=scaleZ;
		#endif
	#elif defined(_PARALLAXMAP) || defined(_PARALLAXMAP_2MAPS) || defined(POM) || defined(DISTANCE_MAP) || defined(EXTRUSION_MAP)
		#if ((defined(POM)) && defined(SILHOUETTE_CURVATURE_MAPPED)) || defined(TRIPLANAR_SELECTIVE)
			float3 viewDirForParallax = ObjSpaceViewDir(v.vertex);
		#else
			// vertex normal, tangent are not guaranteed to be normalized (!)
			// try - 2 simple planes on the scene using the same material, anchored and parent has decreased scale, Unity makes kind of batch (vertices seems to be transformed to world space) ? Anyway mesh tangents, normals get scaled, too and makes total mess with TBN matrices (view direction...)
			v.normal=normalize(v.normal);
			v.tangent.xyz=normalize(v.tangent.xyz);
			float3 binormal = cross( v.normal, v.tangent.xyz ) * v.tangent.w;
			float3x3 rotation = float3x3( v.tangent.xyz, binormal, v.normal );
			float3 viewDirForParallax = mul (rotation, ObjSpaceViewDir(v.vertex));
		#endif
		o.tangentToWorldAndParallax0.w = viewDirForParallax.x;
		o.tangentToWorldAndParallax1.w = viewDirForParallax.y;
		o.tangentToWorldAndParallax2.w = viewDirForParallax.z;
	#endif
	
	#if defined(TRIPLANAR_SELECTIVE)
		#if defined(_TRIPLANAR_WORLD_MAPPING)
			o.tex = float4(normalWorld, v.uv1.x); // pack UV1 here
		#else
			o.tex = float4(v.normal, v.uv1.x); // pack UV1 here
		#endif
	#else
		o.tex = TexCoordsNoTransform(v);
	#endif
	
	UNITY_TRANSFER_FOG(o,o.pos);
	return o;
}

void fragForwardAdd (VertexOutputForwardAdd i, out float4 outCol : SV_Target
#if defined(_2SIDED)
,float facing : VFACE
#endif
#if defined(ZWRITE)
,out float outDepth : DEPTH_SEMANTIC
#endif
)
{
	UNITY_APPLY_DITHER_CROSSFADE(i.pos.xy);

	#if defined(_2SIDED)
		#if UNITY_VFACE_FLIPPED
			facing = -facing;
		#endif
		#if UNITY_VFACE_AFFECTED_BY_PROJECTION
			facing *= _ProjectionParams.x; // take possible upside down rendering into account
		#endif	
		#if defined(TRIPLANAR_SELECTIVE)
			i.tex.xyz *= facing>0 ? 1 : -1;
		#else
			i.tangentToWorldAndParallax2 *= facing>0 ? 1 : -1;
		#endif
	#endif
	
	#if defined(TRIPLANAR_SELECTIVE)
		// unpack UV1
		#if defined(_TRIPLANAR_WORLD_MAPPING)
			float2 secUV=float2(i.tex.w, i.eyeVec.w);
		#else
			float2 secUV=float2(i.tex.w, i.posObject.w);
		#endif		
	#endif
	
	// ------
	float actH;
	float4 SclCurv;
	float3 eyeVec;
	
	float3 tangentBasisScaled;
	
	float2 _ddx;
	float2 _ddy;
	float2 _ddxDet;
	float2 _ddyDet;
	float blendFade;
	
	float3 i_viewDirForParallax;
	float3x3 _TBN;
	float3 worldNormal;
	
	float4 texcoordsNoTransform;
	
	// void	SetupUBER(float4 i_SclCurv, float3 i_eyeVec, float3 i_posWorld, float3 i_posObject, inout float4 i_tex, inout float4 i_tangentToWorldAndParallax0, inout float4 i_tangentToWorldAndParallax1, inout float4 i_tangentToWorldAndParallax2, inout fixed4 vertex_color, out float actH, out float4 SclCurv, out float3 eyeVec, out float3 tangentBasisScaled, out float2 _ddx, out float2 _ddy, out float2 _ddxDet, out float2 _ddyDet, out float blendFade, out float3 i_viewDirForParallax, out float3x3 _TBN, out float3 worldNormal) {
	#if defined(TRIPLANAR_SELECTIVE) && !defined(_TRIPLANAR_WORLD_MAPPING)
		SetupUBER(float4(0,0,0,0), float3(0,0,0), i.posWorld.xyz, i.posObject.xyz, /* inout */ i.tex, /* inout */ i.tangentToWorldAndParallax0, /* inout */ i.tangentToWorldAndParallax1, /* inout */ i.tangentToWorldAndParallax2, /* inout */ i.vertex_color, /* out */ actH, /* out */ SclCurv, /* out */ eyeVec, /* out */ tangentBasisScaled, /* out */ _ddx, /* out */ _ddy, /* out */ _ddxDet, /* out */ _ddyDet, /* out */ blendFade, /* out */ i_viewDirForParallax, /* out */ _TBN, /* out */ worldNormal, /* out */ texcoordsNoTransform);
	#elif defined(POM) || defined(DISTANCE_MAP) || defined(EXTRUSION_MAP)
		SetupUBER(i.SclCurv, float3(0,0,0), i.posWorld.xyz, float3(0,0,0), /* inout */ i.tex, /* inout */ i.tangentToWorldAndParallax0, /* inout */ i.tangentToWorldAndParallax1, /* inout */ i.tangentToWorldAndParallax2, /* inout */ i.vertex_color, /* out */ actH, /* out */ SclCurv, /* out */ eyeVec, /* out */ tangentBasisScaled, /* out */ _ddx, /* out */ _ddy, /* out */ _ddxDet, /* out */ _ddyDet, /* out */ blendFade, /* out */ i_viewDirForParallax, /* out */ _TBN, /* out */ worldNormal, /* out */ texcoordsNoTransform);
	#else
		SetupUBER(float4(0,0,0,0), i.eyeVec.xyz, i.posWorld.xyz, float3(0,0,0), /* inout */ i.tex, /* inout */ i.tangentToWorldAndParallax0, /* inout */ i.tangentToWorldAndParallax1, /* inout */ i.tangentToWorldAndParallax2, /* inout */ i.vertex_color, /* out */ actH, /* out */ SclCurv, /* out */ eyeVec, /* out */ tangentBasisScaled, /* out */ _ddx, /* out */ _ddy, /* out */ _ddxDet, /* out */ _ddyDet, /* out */ blendFade, /* out */ i_viewDirForParallax, /* out */ _TBN, /* out */ worldNormal, /* out */ texcoordsNoTransform);
	#endif
	// ------	

//#if defined(VERTEX_COLOR_RGB_TO_ALBEDO_INDEXED)
//		float3 diffuseTint = i.diffuseTint;
//#else
		float3 diffuseTint = float3(0.5, 0.5, 0.5); // n/u
		float3 diffuseTint2 = float3(0.5, 0.5, 0.5);
//#endif

	FRAGMENT_SETUP_FWDADD(s)
	
	#if defined(ZWRITE)
		s.posWorld.xyz += s.rayLength*s.eyeVec;
	#endif
	
	float2 occ=Occlusion(i.tex, _ddx, _ddy, _ddxDet, _ddyDet, i.vertex_color); // y - translucency/glitter
	#if defined(_TRANSLUCENCY)
		// translucency occlusion might be taken from UV1
		#if defined(TRIPLANAR_SELECTIVE)
			// already unpacked secUV		
		#else
			#if defined(SECONDARY_OCCLUSION_PARALLAXED)
				float2 secUV=((i.tex.xy-_MainTex_ST.zw)/_MainTex_ST.xy - texcoordsNoTransform.xy) + texcoordsNoTransform.zw;
			#else
				float2 secUV=texcoordsNoTransform.zw; // actually we don't need parallax applied as we assume secondary occlusion is low freq maybe
			#endif
		#endif
		secUV = _UVSecOcclusionLightmapPacked==1 ? (secUV * unity_LightmapST.xy + unity_LightmapST.zw) : secUV;
		// translucency mask from UV1
		float translucency_thickness_fromOccMap = tex2Dp(_OcclusionMap, secUV,  ddx(secUV),  ddy(secUV)).AUX_OCCLUSION_CHANNEL;
		// UV0 / UV1 occlusion switch
		float translucency_thickness = _UVSecOcclusion==0 ? occ.y : translucency_thickness_fromOccMap;
	#endif
	
	// push lighting coords
	#if defined(ZWRITE)
		#if defined (SHADOWS_DEPTH) && defined (SPOT)
			// spot lights - more expensive recast World2Shadow matrix...
			i._ShadowCoord = mul (unity_WorldToShadow[0], float4(s.posWorld.xyz,1));
		#elif defined (SHADOWS_CUBE)
			// point light - easy stuff - just push it towards viewing vector
			i._ShadowCoord+=s.rayLength*s.eyeVec;
		#endif
	#endif
	 
	
	#if defined(DIRECTIONAL)
		float3 lightDir = _WorldSpaceLightPos0.xyz;
		UNITY_LIGHT_ATTENUATION(atten, i, s.posWorld.xyz, shadow_atten)
		UnityLight light = AdditiveLight(lightDir, 1); // no dummy atten applied here, shadow atten applied after translucecy suppressing
	#else
		#if UBER_MATCH_ALLOY_LIGHT_FALLOFF
			//
			// match attenuation falloff of Alloy
			//
			float3 lightDir = (_WorldSpaceLightPos0.xyz - s.posWorld.xyz * _WorldSpaceLightPos0.w);
//			#ifndef ALLOY_DISABLE_AREA_LIGHTS
//				float3 lightDirArea = lightDir;
//				float3 _R=reflect( (s.posWorld.xyz-_WorldSpaceCameraPos), s.normalWorld);
//				float3 centerToRay = dot(lightDir, _R) * _R - lightDir;
//				float light_size = _LightColor0.a / _LightPositionRange.w; // lightColor.a*range
//				lightDirArea += centerToRay * saturate(light_size / length(centerToRay));
//				lightDirArea = normalize(lightDirArea);
//			#endif
			float light_distSqr = dot(lightDir, lightDir);
			float light_dist = sqrt(light_distSqr);
			lightDir/=light_dist;
			#ifdef SPOT
				float rangeInv = length(i._LightCoord.xyz) / light_dist;
			#else
				float rangeInv=_LightPositionRange.w; // seems that this works _LightPositionRange.w=1/range
			#endif
			float ratio = light_dist * rangeInv;
			float ratio2 = ratio * ratio;
			float num = saturate(1.0h - (ratio2 * ratio2));
			float latten = (num * num) / (light_distSqr + 1.0h);
			#ifdef POINT_COOKIE
				latten *= texCUBE(_LightTexture0, i._LightCoord).w;
			#endif
			#ifdef SPOT
				latten *= (i._LightCoord.z > 0) * UnitySpotCookie(i._LightCoord);
			#endif			
//			#ifndef ALLOY_DISABLE_AREA_LIGHTS
//				// dir for lighting - area lights corrected
//				// (TODO - currently doesn't work - area lights are more than light dir correction only)
//				lightDir = lightDirArea;		
//			#endif
			UnityLight light = AdditiveLight (lightDir, latten); // light attenuation calculated by Alloy
			float shadow_atten = UNITY_SHADOW_ATTENUATION(i, s.posWorld.xyz); // while shadow_atten we need to pick ourselves
		#else
			//
			// regular Unity's light with default attenuation (w/o shadows though)
			//
			float3 lightDir = normalize(_WorldSpaceLightPos0.xyz - s.posWorld.xyz * _WorldSpaceLightPos0.w);
			UNITY_LIGHT_ATTENUATION(atten, i, s.posWorld.xyz, shadow_atten)
			UnityLight light = AdditiveLight (lightDir, atten);
		#endif
	#endif

	#if (defined(_PARALLAX_POM_SHADOWS) || defined(_POM_DISTANCE_MAP_SHADOWS) || defined(_POM_EXTRUSION_MAP_SHADOWS)) && defined(_UBER_SHADOWS_FORWARDADD)
		#if defined(_SNOW) && !defined(_POM_DISTANCE_MAP_SHADOWS) && !defined(_POM_EXTRUSION_MAP_SHADOWS)
			bool SS_flag=(saturate(s.snowVal*_SnowDeepSmoothen)<0.98);
		#else
			bool SS_flag=true;
		#endif
		if (SS_flag) {
			float3 lightDirInTanSpace=mul(light.dir, transpose(s.tanToWorld));
			#if defined(_SNOW) && !defined(_POM_DISTANCE_MAP_SHADOWS) && !defined(_POM_EXTRUSION_MAP_SHADOWS)
				light.color *= SelfShadows(s.rayPos, s.texture2ObjectRatio, lightDirInTanSpace, s.snowVal);
			#else
				#if defined(_POM_DISTANCE_MAP_SHADOWS) || defined(_POM_EXTRUSION_MAP_SHADOWS)
					light.color *= lerp( SelfShadows(s.rayPos, s.texture2ObjectRatio, lightDirInTanSpace, 0), 1, saturate( distance(s.posWorld.xyz, _WorldSpaceCameraPos) / _DepthReductionDistance ) );
				#else
					light.color *= SelfShadows(s.rayPos, s.texture2ObjectRatio, lightDirInTanSpace, 0);
				#endif				
			#endif
		}
	#endif
	UnityIndirect noIndirect = ZeroIndirect ();
	
	// translucency
	#if defined(_TRANSLUCENCY)
		float3 TL=Translucency(s, light, translucency_thickness, i.vertex_color);
		s.diffColor*=saturate(1-max(max(TL.r, TL.g), TL.b)*TRANSLUCENCY_SUPPRESS_DIFFUSECOLOR);
		shadow_atten=lerp( shadow_atten, 1, saturate( dot(TL,0.3)*_TranslucencySuppressRealtimeShadows ) );
	#endif	
	
	// apply shadows here (they can be suppressed by translucency)
	light.color*=shadow_atten;
	
	#if defined(_GLITTER)
		Glitter(/* inout */ s, i.tex.zw, _ddxDet, _ddyDet, s.posWorld.xyz, i.vertex_color, lerp(1, occ.y, _GlitterMask));
	#endif	
		
	float4 c = UNITY_BRDF_PBS (s.diffColor, s.specColor, s.oneMinusReflectivity, s.smoothness, s.normalWorld, -s.eyeVec, light, noIndirect);
	
	#if defined(_TRANSLUCENCY)
		c.rgb += TL*light.color;
	#endif	
		
	UNITY_APPLY_FOG_COLOR(i.fogCoord, c.rgb, float4(0,0,0,0)); // fog towards black in additive pass

	#if DECAL_PIERCEABLE
		if (_Pierceable == true) {
			float2 screenUV = (i.screenPos.xy / i.screenPos.w);
			#if !defined(SHADER_API_OPENGL) && !defined(SHADER_API_GLCORE) && !defined(SHADER_API_GLES3)
				screenUV.y = _ProjectionParams.x>0 ? 1 - screenUV.y : screenUV.y;
			#endif

			//float piercingDepthBuffer = tex2D(_PiercingDepthBuffer, screenUV).r; // linear depth stored in Rfloat buffer (depth of surface where piercing decal is placed with small offset to prevent fighting)
			//float ldepth = i.screenPos.z; // linear eye depth passed from vertex program
			//float depthFade = 1 - saturate(abs(piercingDepthBuffer - ldepth) * 16);

			float2 piercingBuffer = tex2D(_PiercingBuffer, screenUV).rg;
			float forwardDecalAlpha = piercingBuffer.g * 4;
			float piercingValue = saturate((_PiercingThreshold - piercingBuffer.r) * 20);
			forwardDecalAlpha = 1 - saturate(forwardDecalAlpha); 
			forwardDecalAlpha *= piercingValue;
			s.alpha *= forwardDecalAlpha; // fadeout pixels written by piercing decal
			//s.alpha *= piercingValue; // fadeout pixels written by piercing decal
			c.rgb *= forwardDecalAlpha; // fadeout specular highlights
			//c.rgb *= piercingValue; // remove completely the hole
		}
	#endif

	#if defined(LOD_FADE_CROSSFADE) && (defined(_ALPHABLEND_ON) || defined(_ALPHAPREMULTIPLY_ON))
		s.alpha *= unity_LODFade.x;
	#endif
	outCol=OutputForward (c, s.alpha);
	
	#if defined(ZWRITE)
		//float depthWithOffset = i.posWorld.w+s.rayLength;
		float depthWithOffset = i.posWorld.w*(1+s.rayLength/distance(i.posWorld.xyz, _WorldSpaceCameraPos)); // Z-DEPTH perspective correction
		outDepth = (1.0 - depthWithOffset * _ZBufferParams.w) / (depthWithOffset * _ZBufferParams.z);
	#endif	
}

// ------------------------------------------------------------------
//  Deferred pass

struct VertexOutputDeferred
{
	UNITY_POSITION(pos);
	float4 tex							: TEXCOORD0; // normal in triplanar (.w means UV1 - u coord for triplanar - needed for secondary occlusion)
	#if defined(TRIPLANAR_SELECTIVE) && !defined(_TRIPLANAR_WORLD_MAPPING)
		float4 posObject				: TEXCOORD1; // .w means UV1 - v coord for triplanar (needed for secondary occlusion)
	#elif defined(POM) || defined(DISTANCE_MAP) || defined(EXTRUSION_MAP)
		float4 SclCurv					: TEXCOORD1;
	#else
		float4 eyeVec 					: TEXCOORD1; // .w means UV1 - v coord for triplanar (needed for secondary occlusion)
	#endif
	float4 tangentToWorldAndParallax0	: TEXCOORD2;	// [3x3:tangentToWorld | 1x3:viewDirForParallax] - note: tangents+obj scale in triplanar (tangents in world space when mapping in world space)
	float4 tangentToWorldAndParallax1	: TEXCOORD3;	// (array fails in GLSL optimizer)
	float4 tangentToWorldAndParallax2	: TEXCOORD4;
	float4 ambientOrLightmapUV			: TEXCOORD5;	// SH or Lightmap UVs			
	fixed4 vertex_color					: COLOR0;		// UBER

	#if defined(ZWRITE)
		float4 posWorld					: TEXCOORD6;
	#else
		float3 posWorld					: TEXCOORD6;
	#endif

	float4 screenUV							: TEXCOORD7;

	#if defined(VERTEX_COLOR_RGB_TO_ALBEDO_INDEXED)
		float3 diffuseTint					: TEXCOORD8;
	#elif defined(VERTEX_COLOR_RGB_TO_ALBEDO_DOUBLE_INDEXED)
		float3 diffuseTint					: TEXCOORD8;
		float3 diffuseTint2					: TEXCOORD9;
	#endif

	UNITY_VERTEX_OUTPUT_STEREO
};

#if defined(VERTEX_COLOR_RGB_TO_ALBEDO_INDEXED)
uniform float3 diffuseTintArray[16];
#elif defined(VERTEX_COLOR_RGB_TO_ALBEDO_DOUBLE_INDEXED)
uniform float3 diffuseTintArray[16];
uniform float3 diffuseTintArrayB[16];
#endif


VertexOutputDeferred vertDeferred (VertexInput v)
{
	UNITY_SETUP_INSTANCE_ID(v);
	VertexOutputDeferred o;
	UNITY_INITIALIZE_OUTPUT(VertexOutputDeferred, o);
	UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

	#if defined(POM) || defined(DISTANCE_MAP) || defined(EXTRUSION_MAP)
		float2 Curv=frac(v.uv3);
		float2 Scl=(v.uv3-Curv)/100; // scale represented with 0.01 resolution (fair enough)
		Scl=Scl*_Tan2ObjectMultOffset.xy+_Tan2ObjectMultOffset.zw;
		#if defined(VERTEX_COLOR_CHANNEL_POMZ)
			v.vertex.xyz+=_POM_ExtrudeVolume ? v.normal.xyz*v.color.VERTEX_COLOR_CHANNEL_POMZ*_Depth*max(Scl.x, Scl.y)/max(_MainTex_ST.x, _MainTex_ST.y) : float3(0,0,0);
			// Curv.x==0 - extruded bottom flag
			v.color.VERTEX_COLOR_CHANNEL_POMZ = Curv.x==0 || (!_POM_ExtrudeVolume) ? v.color.VERTEX_COLOR_CHANNEL_POMZ : 1-v.color.VERTEX_COLOR_CHANNEL_POMZ;
			//Curv=0; // no curvature on extruded volumes (we need bottom flag info in parallax function though - so DON'T zero Curv here !)
			// if we don't handle the volume set the curvature data to desired range
			Curv = _POM_ExtrudeVolume ? Curv : Curv*20-10;
		#else
			Curv=Curv*20-10; // Curv=(Curv-0.5)*10; // we assume curvature won't be higher than +/- 10
		#endif
	#endif
	
	o.pos = UnityObjectToClipPos(v.vertex);
	o.screenUV = ComputeScreenPos(o.pos);
	COMPUTE_EYEDEPTH(o.screenUV.z); // used for pierceables, reused below for zwrite

	float4 posWorld = mul(unity_ObjectToWorld, v.vertex);
	o.posWorld.xyz = posWorld.xyz; // UBER - there was implicit truncation here
	#if defined(ZWRITE)
		//COMPUTE_EYEDEPTH(o.posWorld.w);
		o.posWorld.w = o.screenUV.z;
	#endif		
	o.vertex_color = v.color; // UBER

	#if defined(TRIPLANAR_SELECTIVE) && !defined(_TRIPLANAR_WORLD_MAPPING)
		//o.posObject set below
	#elif defined(POM) || defined(DISTANCE_MAP) || defined(EXTRUSION_MAP)
		o.SclCurv=float4(float2(1.0,1.0)/Scl, Curv);
	#else
		o.eyeVec.xyz = posWorld.xyz - _WorldSpaceCameraPos;
		#if defined(TRIPLANAR_SELECTIVE)
			// world mapping
			o.eyeVec.w = v.uv1.y;
		#endif
	#endif
	
	#if defined(TRIPLANAR_SELECTIVE)
		#if defined(_TRIPLANAR_WORLD_MAPPING)
			float3 normalWorld = UnityObjectToWorldNormal(v.normal);
			SetupUBER_VertexData_TriplanarWorld(normalWorld, /* inout */ o.tangentToWorldAndParallax0, /* inout */ o.tangentToWorldAndParallax1, /* inout */ o.tangentToWorldAndParallax2);
		#else
			float scaleX, scaleY, scaleZ;
			SetupUBER_VertexData_TriplanarLocal(v.normal, /* inout */ o.tangentToWorldAndParallax0, /* inout */ o.tangentToWorldAndParallax1, /* inout */ o.tangentToWorldAndParallax2, /* out */ scaleX, /* out */ scaleY, /* out */ scaleZ);
			float3 normalWorld = UnityObjectToWorldNormal(v.normal);
			o.posObject.xyz = v.vertex.xyz;
			o.posObject.w = v.uv1.y; // pack it here
		#endif		
	#elif defined(_TANGENT_TO_WORLD)
		float3x3 tangentToWorld;
		
		// we need to go from tangent to world space for zwrite and parallaxed snow (actually when snow is mapped in worldspace)
		#if defined(RAYLENGTH_AVAILABLE)
			float3 normalWorld = mul((float3x3)unity_ObjectToWorld, v.normal.xyz);
			float3 tangentWorld = mul((float3x3)unity_ObjectToWorld, v.tangent.xyz);
			float3 binormalWorld = mul((float3x3)unity_ObjectToWorld, cross(v.normal.xyz, v.tangent.xyz)*v.tangent.w);
			#ifdef SHADER_TARGET_GLSL
			binormalWorld*=0.9999; // dummy op to cheat HLSL2GLSL optimizer to not be so smart (and buggy) here... It probably tries to make some fancy matrix by matrix calculation
			#endif
			// not normalized basis (we need it for texture 2 worldspace ratio calculations)
			tangentToWorld=float3x3(tangentWorld, binormalWorld, normalWorld);
			normalWorld = normalize(normalWorld); // we need it below for lighting
		#else
			float3 normalWorld = UnityObjectToWorldNormal(v.normal);
			float4 tangentWorld = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);
			tangentToWorld = CreateTangentToWorldPerVertex(normalWorld, tangentWorld.xyz, v.tangent.w);
		#endif


		o.tangentToWorldAndParallax0.xyz = tangentToWorld[0];
		o.tangentToWorldAndParallax1.xyz = tangentToWorld[1];
		o.tangentToWorldAndParallax2.xyz = tangentToWorld[2];
	#else
		float3 normalWorld = UnityObjectToWorldNormal(v.normal);
		o.tangentToWorldAndParallax0.xyz = 0;
		o.tangentToWorldAndParallax1.xyz = 0;
		o.tangentToWorldAndParallax2.xyz = normalWorld;
	#endif

	#ifdef LIGHTMAP_ON
		o.ambientOrLightmapUV.xy = v.uv1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
		o.ambientOrLightmapUV.zw = 0;
	#elif UNITY_SHOULD_SAMPLE_SH
		#if (SHADER_TARGET < 30)
			o.ambientOrLightmapUV.rgb = ShadeSH9(float4(normalWorld, 1.0));
		#else
			// Optimization: L2 per-vertex, L0..L1 per-pixel
			o.ambientOrLightmapUV.rgb = ShadeSH3Order(float4(normalWorld, 1.0));
		#endif
	#endif
	
	#ifdef DYNAMICLIGHTMAP_ON
		o.ambientOrLightmapUV.zw = v.uv2.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
	#endif
	
	#if defined(TRIPLANAR_SELECTIVE)
		#if defined(_TRIPLANAR_WORLD_MAPPING)
			// .w component not used
		#else
			o.tangentToWorldAndParallax0.w=scaleX;
			o.tangentToWorldAndParallax1.w=scaleY;
			o.tangentToWorldAndParallax2.w=scaleZ;
		#endif
	#elif defined(_PARALLAXMAP) || defined(_PARALLAXMAP_2MAPS) || defined(POM) || defined(DISTANCE_MAP) || defined(EXTRUSION_MAP)
		#if ((defined(POM)) && defined(SILHOUETTE_CURVATURE_MAPPED)) || defined(TRIPLANAR_SELECTIVE)
			float3 viewDirForParallax = ObjSpaceViewDir(v.vertex);
		#else
			// vertex normal, tangent are not guaranteed to be normalized (!)
			// try - 2 simple planes on the scene using the same material, anchored and parent has decreased scale, Unity makes kind of batch (vertices seems to be transformed to world space) ? Anyway mesh tangents, normals get scaled, too and makes total mess with TBN matrices (view direction...)
			v.normal=normalize(v.normal);
			v.tangent.xyz=normalize(v.tangent.xyz);
			float3 binormal = cross( v.normal, v.tangent.xyz ) * v.tangent.w;
			float3x3 rotation = float3x3( v.tangent.xyz, binormal, v.normal );
			float3 viewDirForParallax = mul (rotation, ObjSpaceViewDir(v.vertex));
		#endif
		o.tangentToWorldAndParallax0.w = viewDirForParallax.x;
		o.tangentToWorldAndParallax1.w = viewDirForParallax.y;
		o.tangentToWorldAndParallax2.w = viewDirForParallax.z;
	#endif
	
	#if defined(TRIPLANAR_SELECTIVE)
		#if defined(_TRIPLANAR_WORLD_MAPPING)
			o.tex = float4(normalWorld, v.uv1.x); // pack UV1 here
		#else
			o.tex = float4(v.normal, v.uv1.x);
		#endif
	#else
		o.tex = TexCoordsNoTransform(v);
	#endif

	#if defined(VERTEX_COLOR_RGB_TO_ALBEDO_INDEXED)
		uint idx = uint(clamp(floor(v.color.VERTEX_COLOR_RGB_TO_ALBEDO_INDEXED*255),0,15));
		o.diffuseTint = diffuseTintArray[idx];
	#elif defined(VERTEX_COLOR_RGB_TO_ALBEDO_DOUBLE_INDEXED)
		uint idx = uint(clamp(frac(v.color.VERTEX_COLOR_RGB_TO_ALBEDO_DOUBLE_INDEXED * 16)*16, 0, 15));
		o.diffuseTint = diffuseTintArray[idx];
		idx = uint(clamp(floor(v.color.VERTEX_COLOR_RGB_TO_ALBEDO_DOUBLE_INDEXED * 16), 0, 15));
		o.diffuseTint2 = diffuseTintArrayB[idx];
	#endif
		
	return o;
}

// mask for decals to store in gfubber2.a (normals - 2 bits)
fixed _DecalMask;
#if defined(_SNOW)
	fixed _DecalMaskForSnow;
	fixed _DecalMaskForSnowThreshold;
#endif

void fragDeferred (
	VertexOutputDeferred i,
	out float4 outGBuffer0 : SV_Target0,			// RT0: diffuse color (rgb), occlusion (a)
	out float4 outGBuffer1 : SV_Target1,			// RT1: spec color (rgb), smoothness (a)
	out float4 outGBuffer2 : SV_Target2,			// RT2: normal (rgb), Decal mask (a)
	out float4 outEmission : SV_Target3			// RT3: emission (rgb), translucency encoded (a)
#if defined(SHADOWS_SHADOWMASK) && (UNITY_ALLOWED_MRT_COUNT > 4)
	, out float4 outShadowMask : SV_Target4       // RT4: shadowmask (rgba)
#endif
#if defined(_2SIDED)
,float facing : VFACE
#endif
#if defined(ZWRITE)
,out float outDepth : DEPTH_SEMANTIC
#endif	
)
{
    #if (SHADER_TARGET < 30)
        outGBuffer0 = 1;
        outGBuffer1 = 1;
        outGBuffer2 = 0;
        outEmission = 0;
        #if defined(SHADOWS_SHADOWMASK) && (UNITY_ALLOWED_MRT_COUNT > 4)
            outShadowMask = 1;
        #endif
        return;
    #endif

	UNITY_APPLY_DITHER_CROSSFADE(i.pos.xy);

	#if DECAL_PIERCEABLE
	if (_Pierceable == true) {
		float4 screen_uv = float4(i.screenUV.xy / i.screenUV.w, 0, 0);
		float pierceMaskDepth = tex2Dlod(_PiercingBuffer, screen_uv).r; // linear depth stored in Rfloat buffer (depth of surface where piercing decal is placed with small offset to prevent fighting)
		float ldepth = i.screenUV.z; // linear eye depth passed from vertex program
		clip(pierceMaskDepth > ldepth ? -1 : 1);
	}
	#endif
	
	#if defined(_2SIDED)
		#if UNITY_VFACE_FLIPPED
			facing = -facing;
		#endif
		#if UNITY_VFACE_AFFECTED_BY_PROJECTION
			facing *= _ProjectionParams.x; // take possible upside down rendering into account
		#endif	
		#if defined(TRIPLANAR_SELECTIVE)
			i.tex.xyz *= facing>0 ? 1 : -1;
		#else
			i.tangentToWorldAndParallax2 *= facing>0 ? 1 : -1;
		#endif
	#endif
		
	#if defined(TRIPLANAR_SELECTIVE)
		// unpack UV1
		#if defined(_TRIPLANAR_WORLD_MAPPING)
			float2 secUV=float2(i.tex.w, i.eyeVec.w);
		#else
			float2 secUV=float2(i.tex.w, i.posObject.w);
		#endif		
	#endif
		
	// ------
	float actH;
	float4 SclCurv;
	float3 eyeVec;
	
	float3 tangentBasisScaled;
	
	float2 _ddx;
	float2 _ddy;
	float2 _ddxDet;
	float2 _ddyDet;
	float blendFade;
	
	float3 i_viewDirForParallax;
	float3x3 _TBN;
	float3 worldNormal;
	
	float4 texcoordsNoTransform;
	
	// void	SetupUBER(float4 i_SclCurv, float3 i_eyeVec, float3 i_posWorld, float3 i_posObject, inout float4 i_tex, inout float4 i_tangentToWorldAndParallax0, inout float4 i_tangentToWorldAndParallax1, inout float4 i_tangentToWorldAndParallax2, inout fixed4 vertex_color, out float actH, out float4 SclCurv, out float3 eyeVec, out float3 tangentBasisScaled, out float2 _ddx, out float2 _ddy, out float2 _ddxDet, out float2 _ddyDet, out float blendFade, out float3 i_viewDirForParallax, out float3x3 _TBN, out float3 worldNormal) {
	#if defined(TRIPLANAR_SELECTIVE) && !defined(_TRIPLANAR_WORLD_MAPPING)
		SetupUBER(float4(0,0,0,0), float3(0,0,0), IN_WORLDPOS(i), i.posObject.xyz, /* inout */ i.tex, /* inout */ i.tangentToWorldAndParallax0, /* inout */ i.tangentToWorldAndParallax1, /* inout */ i.tangentToWorldAndParallax2, /* inout */ i.vertex_color, /* out */ actH, /* out */ SclCurv, /* out */ eyeVec, /* out */ tangentBasisScaled, /* out */ _ddx, /* out */ _ddy, /* out */ _ddxDet, /* out */ _ddyDet, /* out */ blendFade, /* out */ i_viewDirForParallax, /* out */ _TBN, /* out */ worldNormal, /* out */ texcoordsNoTransform);
	#elif defined(POM) || defined(DISTANCE_MAP) || defined(EXTRUSION_MAP)
		SetupUBER(i.SclCurv, float3(0,0,0), IN_WORLDPOS(i), float3(0,0,0), /* inout */ i.tex, /* inout */ i.tangentToWorldAndParallax0, /* inout */ i.tangentToWorldAndParallax1, /* inout */ i.tangentToWorldAndParallax2, /* inout */ i.vertex_color, /* out */ actH, /* out */ SclCurv, /* out */ eyeVec, /* out */ tangentBasisScaled, /* out */ _ddx, /* out */ _ddy, /* out */ _ddxDet, /* out */ _ddyDet, /* out */ blendFade, /* out */ i_viewDirForParallax, /* out */ _TBN, /* out */ worldNormal, /* out */ texcoordsNoTransform);
	#else
		SetupUBER(float4(0,0,0,0), i.eyeVec.xyz, IN_WORLDPOS(i), float3(0,0,0), /* inout */ i.tex, /* inout */ i.tangentToWorldAndParallax0, /* inout */ i.tangentToWorldAndParallax1, /* inout */ i.tangentToWorldAndParallax2, /* inout */ i.vertex_color, /* out */ actH, /* out */ SclCurv, /* out */ eyeVec, /* out */ tangentBasisScaled, /* out */ _ddx, /* out */ _ddy, /* out */ _ddxDet, /* out */ _ddyDet, /* out */ blendFade, /* out */ i_viewDirForParallax, /* out */ _TBN, /* out */ worldNormal, /* out */ texcoordsNoTransform);
	#endif
	// ------	
	
#if defined(VERTEX_COLOR_RGB_TO_ALBEDO_INDEXED)
	float3 diffuseTint=i.diffuseTint;
	float3 diffuseTint2 = float3(0.5, 0.5, 0.5);
#elif defined(VERTEX_COLOR_RGB_TO_ALBEDO_DOUBLE_INDEXED)
	float3 diffuseTint = i.diffuseTint;
	float3 diffuseTint2 = i.diffuseTint2;
#else
	float3 diffuseTint = float3(0.5, 0.5, 0.5);
	float3 diffuseTint2 = float3(0.5, 0.5, 0.5);
#endif


	FRAGMENT_SETUP(s)

	// no analytic lights in this pass
	UnityLight dummyLight = DummyLight ();
	float atten = 1;

	// only GI
	float2 occ=Occlusion(i.tex, _ddx, _ddy, _ddxDet, _ddyDet, i.vertex_color); // y - translucency/glitter
	float occlusion = occ.x;
	#if defined(OCCLUSION_VERTEX_COLOR_CHANNEL)
		occlusion*=i.vertex_color.OCCLUSION_VERTEX_COLOR_CHANNEL;
	#endif
	#if defined(_TWO_LAYERS)
		occlusion = LerpOneTo(occlusion, lerp(_OcclusionStrength2, _OcclusionStrength, i.__VERTEX_COLOR_CHANNEL_LAYER));
	#else
		occlusion = LerpOneTo(occlusion, _OcclusionStrength);
	#endif

	#if defined(_TRANSLUCENCY)
		float translucency_thickness_fromOccMap = 1;
	#endif
	if (_Occlusion_from_albedo_alpha) { // uniform bool (float for sake of d3d9 compatibility)
		// possible 2ndary occlusion
		// primary occlusion from diffuse A, secondary from _OcclusionMap
		#if defined(TRIPLANAR_SELECTIVE)
			// already unpacked secUV
		#else
			#if defined(SECONDARY_OCCLUSION_PARALLAXED)
				float2 secUV=((i.tex.xy-_MainTex_ST.zw)/_MainTex_ST.xy - texcoordsNoTransform.xy) + texcoordsNoTransform.zw;
			#else
				float2 secUV=texcoordsNoTransform.zw; // actually we don't need parallax applied as we assume secondary occlusion is low freq maybe
			#endif
		#endif
		secUV = _UVSecOcclusionLightmapPacked==1 ? (secUV * unity_LightmapST.xy + unity_LightmapST.zw) : secUV;
		float4 occVal = tex2Dp(_OcclusionMap, secUV,  ddx(secUV),  ddy(secUV));
		float2 occ2 = float2(occVal.AMBIENT_OCCLUSION_CHANNEL, occVal.AUX_OCCLUSION_CHANNEL);
		// UV0 / UV1 occlusion switch
		occlusion *= (_UVSecOcclusion==0) ? 1 : lerp(1, occ2.x, _SecOcclusionStrength);
		#if defined(_TRANSLUCENCY)
			// translucency mask from UV1
			translucency_thickness_fromOccMap = occ2.y;
		#endif
	}
	
	#if defined(_SNOW)
		occlusion*=lerp(1, s.dissolveMaskValue, s.snowVal*_SnowDissolveMaskOcclusion);
	#endif	
	#if defined(TRIPLANAR_SELECTIVE)
		occlusion*=lerp(1, blendFade, _TriplanarBlendAmbientOcclusion);
	#endif
	#if defined(_SNOW)
		occlusion=lerp(occlusion, 1, saturate(s.snowVal*_SnowDeepSmoothen*0.15));
	#endif	
			
	#if defined(_TRANSLUCENCY)
		// UV0 / UV1 occlusion switch
		float translucency_thickness = _UVSecOcclusion==0 ? occ.y : translucency_thickness_fromOccMap;
		translucency_thickness=lerp(1, translucency_thickness, _TranslucencyOcclusion);
	#endif	

#if UNITY_ENABLE_REFLECTION_BUFFERS
	bool sampleReflectionsInDeferred = false;
#else
	bool sampleReflectionsInDeferred = true;
#endif
	UnityGI gi = FragmentGI(s, occlusion, i.ambientOrLightmapUV, atten, dummyLight, sampleReflectionsInDeferred);


	// baked light POM self-shadows
	bool SS_flag;
	#if defined(_POM_BAKED_SELF_SHADOWS) && (defined(_PARALLAX_POM_SHADOWS) || defined(_POM_DISTANCE_MAP_SHADOWS) || defined(_POM_EXTRUSION_MAP_SHADOWS)) && defined(LIGHTMAP_ON) && defined(DIRLIGHTMAP_SEPARATE)
		//float sNdotL=dot(s.tanToWorld[2].xyz, gi.light.dir);
		//if (sNdotL>0) {
		//	float3 lightDirInTanSpace=mul(s.tanToWorld, gi.light.dir);
		//	gi.light.color *= lerp( 1, SelfShadows(s.rayPos, s.texture2ObjectRatio, lightDirInTanSpace), saturate(sNdotL*30));
		//}
		#if defined(_SNOW) && !defined(_POM_DISTANCE_MAP_SHADOWS) && !defined(_POM_EXTRUSION_MAP_SHADOWS)
			SS_flag=(saturate(s.snowVal*_SnowDeepSmoothen)<0.98);
		#else
			SS_flag=true;
		#endif
		if (SS_flag) {
			float3 lightDirInTanSpace=mul(s.tanToWorld, gi.light.dir); // named tanToworld but this mul() actually works the opposite (as I swapped params in mul)
			#if defined(_SNOW) && !defined(_POM_DISTANCE_MAP_SHADOWS) && !defined(_POM_EXTRUSION_MAP_SHADOWS)
				gi.light.color *= SelfShadows(s.rayPos, s.texture2ObjectRatio, lightDirInTanSpace, s.snowVal);
			#else
				#if defined(_POM_DISTANCE_MAP_SHADOWS) || defined(_POM_EXTRUSION_MAP_SHADOWS)
					gi.light.color *= lerp( SelfShadows(s.rayPos, s.texture2ObjectRatio, lightDirInTanSpace, 0), 1, saturate( distance(i.posWorld, _WorldSpaceCameraPos) / _DepthReductionDistance ) );
				#else
					gi.light.color *= SelfShadows(s.rayPos, s.texture2ObjectRatio, lightDirInTanSpace, 0);
				#endif				
			#endif
		}
	#endif		
	
	#if defined(_GLITTER)
		Glitter(/* inout */ s, i.tex.zw, _ddxDet, _ddyDet, i.posWorld.xyz, i.vertex_color, lerp(1, occ.y, _GlitterMask));
	#endif
		
	float3 emissiveColor = UNITY_BRDF_PBS(s.diffColor, s.specColor, s.oneMinusReflectivity, s.smoothness, s.normalWorld, -s.eyeVec, gi.light, gi.indirect).rgb;

	#if defined(_GLITTER) && UNITY_HDR_ON
		emissiveColor += s.specColor * ShadeSH9(float4(s.normalWorld, 1))*occlusion; // in deferred gbuffer for spec is LDR, we need to add it here directly to HDR light/emission gbuffer
	#endif

	// emissiveness always available in UBER
	#if defined(_SNOW)
		float snowBlur=_SnowDeepSmoothen*4*s.snowVal; // currently not used
		float3 snowEmissionDamp=LerpWhiteTo(_SnowEmissionTransparency, s.snowVal);
	#else
		float snowBlur=0; // not used
		float3 snowEmissionDamp=1;
	#endif

	#if defined(EMISSION_AT_THE_OTHER_SIDE)
		snowEmissionDamp *= saturate(dot(-i.tangentToWorldAndParallax2, DeferredLightDir(i.posWorld.xyz))*4);
	#endif

	emissiveColor += Emission(i.tex.xyzw, i.vertex_color, _ddx, _ddy, snowBlur)*snowEmissionDamp; // UBER - 4 components (main uv, detail uv) & vertex colors
	emissiveColor += s.additionalEmission*snowEmissionDamp; // UBER - detail/wet emission
	
	#ifndef UNITY_HDR_ON
		emissiveColor.rgb = exp2(-emissiveColor.rgb);
	#endif
	
	
	// translucency
	#if defined(_TRANSLUCENCY)
		float TranslucencyColor_a=_TranslucencyColor.a;
		#if defined(_TWO_LAYERS)
			TranslucencyColor_a=lerp(_TranslucencyColor2.a, _TranslucencyColor.a, i.__VERTEX_COLOR_CHANNEL_LAYER);
		#endif
		#if defined(_SNOW)
			translucency_thickness*=lerp(TranslucencyColor_a,_SnowTranslucencyColor.a, s.snowVal);
		#else
			translucency_thickness*=TranslucencyColor_a;
		#endif	
	#endif	

	// realtime light POM self-shadows
	float SS=1;
	#if defined(_POM_REALTIME_SELF_SHADOWS) && (defined(_PARALLAX_POM_SHADOWS) || defined(_POM_DISTANCE_MAP_SHADOWS) || defined(_POM_EXTRUSION_MAP_SHADOWS))
		float3 lightDir=(DeferredLightDir(i.posWorld.xyz));
		#if defined(_SNOW) && !defined(_POM_DISTANCE_MAP_SHADOWS) && !defined(_POM_EXTRUSION_MAP_SHADOWS)
			SS_flag=dot(lightDir, s.normalWorld)>0 && (saturate(s.snowVal*_SnowDeepSmoothen)<0.98);
		#else
			SS_flag=dot(lightDir, s.normalWorld)>0;
		#endif
		if (SS_flag) {
			float3 lightDirInTanSpace=mul(s.tanToWorld, lightDir); // named tanToworld but this mul() actually works the opposite (as I swapped params in mul)
			#if defined(_SNOW) && !defined(_POM_DISTANCE_MAP_SHADOWS) && !defined(_POM_EXTRUSION_MAP_SHADOWS)
				SS = SelfShadows(s.rayPos, s.texture2ObjectRatio, lightDirInTanSpace, s.snowVal);
			#else
				#if defined(_POM_DISTANCE_MAP_SHADOWS) || defined(_POM_EXTRUSION_MAP_SHADOWS)
					SS = lerp( SelfShadows(s.rayPos, s.texture2ObjectRatio, lightDirInTanSpace, 0), 1, saturate( distance(i.posWorld, _WorldSpaceCameraPos) / _DepthReductionDistance ) );
				#else
					SS = SelfShadows(s.rayPos, s.texture2ObjectRatio, lightDirInTanSpace, 0);
				#endif				
			#endif
		}
	#endif		

	// HDR only (we store 0..2047 2^11 integer value in float precision significand)
	float encoded = 0;
	#if defined(_TRANSLUCENCY)
		encoded = floor(saturate(translucency_thickness*_TranslucencyStrength)*15); // 4 bits - 0..15 translucency levels
		encoded *= 4; // shift left 2 bits to make room for translucency index
		encoded += _TranslucencyDeferredLightIndex; // + 0..3 light color index
	#endif
	encoded *= 4; // shift left 2 bits to make room for self shadowing value
	#if defined(_POM_REALTIME_SELF_SHADOWS) && (defined(_PARALLAX_POM_SHADOWS) || defined(_POM_DISTANCE_MAP_SHADOWS) || defined(_POM_EXTRUSION_MAP_SHADOWS))
		encoded += floor((1 - SS) * 3); // 0..3 integer self-shadowing range
	#endif
	encoded *= 8; // shift left 3 bits to make room for wetness value
	#if defined(_WETNESS)
		// make sure s.Wetness is normalized 0..1 !
		encoded += floor(s.Wetness * 7); // 0..7 integer wetness range
	#elif defined(_SNOW)
//		encoded += floor( saturate((_DecalMaskForSnowThreshold - s.snowVal)/_DecalMaskForSnowThreshold) * 7); // 0..7 integer range
//		encoded += floor(saturate(s.snowVal) * 7); // 0..7 integer range
	#endif
	#if defined(_TRANSLUCENCY) || (defined(_POM_REALTIME_SELF_SHADOWS) && (defined(_PARALLAX_POM_SHADOWS) || defined(_POM_DISTANCE_MAP_SHADOWS) || defined(_POM_EXTRUSION_MAP_SHADOWS))) || defined(_WETNESS)
		// any of above props written
		encoded = -encoded; // negative number means we encoded values, positive value is supposed to be 1 only
	#else
		encoded = 1; // default value written by Unity standard shader which means - we've got all props zeroed (no translucency, SS nor wetness)
	#endif

	#if defined(_SNOW)
		fixed DecalMask = s.snowVal > _DecalMaskForSnowThreshold ? _DecalMaskForSnow : _DecalMask;
	#else
		fixed DecalMask = _DecalMask;
	#endif

	UnityStandardData data;
	data.diffuseColor	= s.diffColor;
	data.occlusion		= occlusion;		
	data.specularColor	= s.specColor;
	data.smoothness		= s.smoothness;	
	data.normalWorld	= s.normalWorld;

	UnityStandardDataToGbuffer(data, outGBuffer0, outGBuffer1, outGBuffer2);

	outGBuffer2.w = DecalMask; // UBER (decal mask)
	outEmission = float4(emissiveColor, encoded); // encoded UBER props

	#if defined(SHADOWS_SHADOWMASK) && (UNITY_ALLOWED_MRT_COUNT > 4)
		outShadowMask = UnityGetRawBakedOcclusions(i.ambientOrLightmapUV.xy, i.posWorld.xyz);
	#endif

	#if defined(ZWRITE)
		//float depthWithOffset = i.posWorld.w+s.rayLength;
		float depthWithOffset = i.posWorld.w*(1+s.rayLength/distance(i.posWorld.xyz, _WorldSpaceCameraPos)); // Z-DEPTH perspective correction
		outDepth = (1.0 - depthWithOffset * _ZBufferParams.w) / (depthWithOffset * _ZBufferParams.z);
	#endif	
}					


// ------------------------------------------------------------------------------------
//
// tessellation
//
#if defined(_TESSELLATION) && defined(UNITY_CAN_COMPILE_TESSELLATION) && !defined(UNITY_PASS_META)

	struct UnityTessellationFactors {
		float edge[3] : SV_TessFactor;
		float inside : SV_InsideTessFactor;
	};

	// tessellation vertex shader
	struct InternalTessInterp_appdata {
	  float4 vertex : INTERNALTESSPOS;
	  float3 normal : NORMAL;
	  float2 uv1 : TEXCOORD1;
	  float2 uv2 : TEXCOORD2;
	  float4 color : COLOR;
	  #if !defined(TRIPLANAR_SELECTIVE)
	  float4 tangent : TANGENT;
	  float2 uv0 : TEXCOORD0;
	  #endif
	  #if defined(UNITY_SUPPORT_INSTANCING) && defined(INSTANCING_ON)
		uint instanceID : TEXCOORD3;
	  #endif
	};
	InternalTessInterp_appdata tessvert_surf (VertexInput v) {
	  InternalTessInterp_appdata o;
	  o.vertex = v.vertex;
	  o.normal = v.normal;
	  o.uv1 = v.uv1;
	  o.uv2 = v.uv2;
	  o.color = v.color;
	  #if !defined(TRIPLANAR_SELECTIVE)
	  o.tangent = v.tangent;
	  o.uv0 = v.uv0;
	  #endif
	  UNITY_TRANSFER_INSTANCE_ID(v, o);
	  return o;
	}

	// tessellation hull constant shader
	UnityTessellationFactors hsconst_surf (InputPatch<InternalTessInterp_appdata,3> v) {
	  UnityTessellationFactors o;
	  float4 tf;
	  VertexInput vi[3];
	  vi[0].vertex = v[0].vertex;
	  vi[0].normal = v[0].normal;
	  vi[0].uv1 = v[0].uv1;
	  vi[0].uv2 = v[0].uv2;
	  vi[0].color = v[0].color;
	  vi[1].vertex = v[1].vertex;
	  vi[1].normal = v[1].normal;
	  vi[1].uv1 = v[1].uv1;
	  vi[1].uv2 = v[1].uv2;
	  vi[1].color = v[1].color;
	  vi[2].vertex = v[2].vertex;
	  vi[2].normal = v[2].normal;
	  vi[2].uv1 = v[2].uv1;
	  vi[2].uv2 = v[2].uv2;
	  vi[2].color = v[2].color;
	  #if !defined(TRIPLANAR_SELECTIVE)
	  vi[0].tangent = v[0].tangent;
	  vi[0].uv0 = v[0].uv0;
	  vi[1].tangent = v[1].tangent;
	  vi[1].uv0 = v[1].uv0;
	  vi[2].tangent = v[2].tangent;
	  vi[2].uv0 = v[2].uv0;
	  #endif
	  UNITY_TRANSFER_INSTANCE_ID(v[0], vi[0]); // v[0].instanceID is actually the same as v[1].instanceID and v[2].instanceID (uniform for whole mesh)
	  UNITY_TRANSFER_INSTANCE_ID(v[1], vi[1]);
	  UNITY_TRANSFER_INSTANCE_ID(v[2], vi[2]);
	  tf = tessDistanceWithEdgeLimit(vi[0], vi[1], vi[2]);
	  o.edge[0] = tf.x; o.edge[1] = tf.y; o.edge[2] = tf.z; o.inside = tf.w;
	  return o;
	}

	// tessellation hull shader
	[UNITY_domain("tri")]
	[UNITY_partitioning("fractional_odd")]
	[UNITY_outputtopology("triangle_cw")]
	[UNITY_patchconstantfunc("hsconst_surf")]
	[UNITY_outputcontrolpoints(3)]
	InternalTessInterp_appdata hs_surf (InputPatch<InternalTessInterp_appdata,3> v, uint id : SV_OutputControlPointID) {
	  return v[id];
	}

	/* _Paint3DAccumulator_ */
	// tessellation domain shader
	[UNITY_domain("tri")]
	v2f_struct ds_surfPaint3DAccumulator (UnityTessellationFactors tessFactors, const OutputPatch<InternalTessInterp_appdata,3> vi, float3 bary : SV_DomainLocation) {
	  VertexInput v;
	  v.vertex = vi[0].vertex*bary.x + vi[1].vertex*bary.y + vi[2].vertex*bary.z;
	  v.normal = vi[0].normal*bary.x + vi[1].normal*bary.y + vi[2].normal*bary.z;
	  v.uv1 = vi[0].uv1*bary.x + vi[1].uv1*bary.y + vi[2].uv1*bary.z;
	  v.uv2 = vi[0].uv2*bary.x + vi[1].uv2*bary.y + vi[2].uv2*bary.z;
	  v.color = vi[0].color*bary.x + vi[1].color*bary.y + vi[2].color*bary.z;
	  #if !defined(TRIPLANAR_SELECTIVE)
	  v.tangent = vi[0].tangent*bary.x + vi[1].tangent*bary.y + vi[2].tangent*bary.z;
	  v.uv0 = vi[0].uv0*bary.x + vi[1].uv0*bary.y + vi[2].uv0*bary.z;
	  #endif
	  UNITY_TRANSFER_INSTANCE_ID(vi[0], v); // all vi[n] has the same instanceID transferred

	  //
	  // compute displacement
	  //
	  #if defined(_TESSELLATION_DISPLACEMENT)
		fixed4 vertex_color=v.color;
		float3 normalWorld = UnityObjectToWorldNormal(v.normal);
		
		float4 posWorld = mul(unity_ObjectToWorld, v.vertex);
		
		#if defined(_SNOW)
			float _snow_val = _SnowColorAndCoverage.a*__VERTEX_COLOR_CHANNEL_SNOW;
			_snow_val *= saturate((posWorld.y-_SnowHeightThreshold)/_SnowHeightThresholdTransition);
			_snow_val = saturate( _snow_val - (1-normalWorld.y)*_SnowSlopeDamp );
			_snow_val *= _SnowLevelFromGlobal ? (1-_UBER_GlobalSnowDamp) : 1;
		#endif
	  
		float d=0; // displacement value
		#if defined(TRIPLANAR_SELECTIVE)
			#if defined(_TRIPLANAR_WORLD_MAPPING)
				float3 normBlend=normalWorld;
				float3 posUVZ=posWorld.xyz;
				float3 blendVal = abs(normBlend);
			#else
				float scaleX = length(float3(unity_ObjectToWorld[0][0], unity_ObjectToWorld[1][0], unity_ObjectToWorld[2][0]));
				float scaleY = length(float3(unity_ObjectToWorld[0][1], unity_ObjectToWorld[1][1], unity_ObjectToWorld[2][1]));
				float scaleZ = length(float3(unity_ObjectToWorld[0][2], unity_ObjectToWorld[1][2], unity_ObjectToWorld[2][2]));
				
				float3 objScale=float3(scaleX, scaleY, scaleZ);
				float3 normObj=v.normal;
				float3 normBlend=normObj;
				float3 normObjScaled=normalize(normObj/objScale);
				float3 posUVZ=v.vertex.xyz*objScale;
				float3 blendVal = abs(normObjScaled);
			#endif	
			
			#if defined(_SNOW)
				float level=_SnowDeepSmoothen*saturate(_snow_val-0.3);
			#else
				float level=0;
			#endif
						

			
			/*
			struct appdata_P3DA
			{
				float4 vertex : POSITION;
				#ifdef _CUSTOM_VERTEX_DISPLACEMENT_
				float3 normal : NORMAL;
				#endif
				float2 uv : TEXCOORD0;
			};

			struct v2f_P3DA
			{
				float2 uv : TEXCOORD0;
				float3 worldPos : TEXCOORD1;
				float4 vertex : SV_POSITION;
				#ifdef _CUSTOM_VERTEX_DISPLACEMENT_
				float3 normal : TEXCOORD2;
				#endif
			};
			*/
			/*
			appdata_P3DA aP3DA;
			aP3DA.vertex = v.vertex;
			#ifdef _CUSTOM_VERTEX_DISPLACEMENT_
			aP3DA.normal = v.normal;
			#endif
			aP3DA.uv = v.uv1;
			float vertexHeight = 0;
			v2f_P3DA ret = Paint3DAccumulatorVertexLogic_P0(aP3DA, vertexHeight);
			#ifdef _CUSTOM_VERTEX_DISPLACEMENT_
			v.normal = ret.normal;
			#endif
			v.uv1 = ret.uv;
			*/
			
			

			float3 uvz = posUVZ.xyz*_MainTex_ST.xxx;
			float3 hVal = float3(tex2Dlod(_ParallaxMap, (normBlend.x>0) ? float4(uvz.zy, level.xx) : float4(-uvz.z,uvz.y, level.xx)).PARALLAX_CHANNEL, tex2Dlod(_ParallaxMap, (normBlend.y>0) ? float4(uvz.xz, level.xx) : float4(-uvz.x,uvz.z, level.xx)).PARALLAX_CHANNEL, tex2Dlod(_ParallaxMap, (normBlend.z>0) ? float4(uvz.yx, level.xx) : float4(-uvz.y,uvz.x, level.xx)).PARALLAX_CHANNEL);
			#if defined(_TWO_LAYERS)
				float3 uvz2 = posUVZ.xyz*_DetailAlbedoMap_ST.xxx;
				#if defined(_PARALLAXMAP_2MAPS)
					float3 hVal2 = float3(tex2Dlod(_ParallaxMap2, (normBlend.x>0) ? float4(uvz2.zy, level.xx) : float4(-uvz2.z,uvz2.y, level.xx)).PARALLAX_CHANNEL, tex2Dlod(_ParallaxMap2, (normBlend.y>0) ? float4(uvz2.xz, level.xx) : float4(-uvz2.x,uvz2.z, level.xx)).PARALLAX_CHANNEL, tex2Dlod(_ParallaxMap2, (normBlend.z>0) ? float4(uvz2.yx, level.xx) : float4(-uvz2.y,uvz2.x, level.xx)).PARALLAX_CHANNEL);
				#else
					float3 hVal2 = float3(tex2Dlod(_ParallaxMap2, (normBlend.x>0) ? float4(uvz2.zy, level.xx) : float4(-uvz2.z,uvz2.y, level.xx)).PARALLAX_CHANNEL_2ND_LAYER, tex2Dlod(_ParallaxMap2, (normBlend.y>0) ? float4(uvz2.xz, level.xx) : float4(-uvz2.x,uvz2.z, level.xx)).PARALLAX_CHANNEL_2ND_LAYER, tex2Dlod(_ParallaxMap2, (normBlend.z>0) ? float4(uvz2.yx, level.xx) : float4(-uvz2.y,uvz2.x, level.xx)).PARALLAX_CHANNEL_2ND_LAYER);
				#endif
				hVal = lerp( hVal2, hVal, __VERTEX_COLOR_CHANNEL_LAYER);
			#endif
			/*
			hVal += float3(_ReadVertexDataFromRT( (normBlend.x>0) ? float4(uvz.zy, level.xx) : float4(-uvz.z,uvz.y, level.xx)).PARALLAX_CHANNEL, _ReadVertexDataFromRT( (normBlend.y>0) ? float4(uvz.xz, level.xx) : float4(-uvz.x,uvz.z, level.xx)).PARALLAX_CHANNEL, _ReadVertexDataFromRT( (normBlend.z>0) ? float4(uvz.yx, level.xx) : float4(-uvz.y,uvz.x, level.xx)).PARALLAX_CHANNEL);
			#if defined(_TWO_LAYERS)
				//uvz2 = posUVZ.xyz*_DetailAlbedoMap_ST.xxx;
				#if defined(_PARALLAXMAP_2MAPS)
					hVal2 += float3(_ReadVertexDataFromRT( (normBlend.x>0) ? float4(uvz2.zy, level.xx) : float4(-uvz2.z,uvz2.y, level.xx)).PARALLAX_CHANNEL, _ReadVertexDataFromRT( (normBlend.y>0) ? float4(uvz2.xz, level.xx) : float4(-uvz2.x,uvz2.z, level.xx)).PARALLAX_CHANNEL, _ReadVertexDataFromRT( (normBlend.z>0) ? float4(uvz2.yx, level.xx) : float4(-uvz2.y,uvz2.x, level.xx)).PARALLAX_CHANNEL);
				#else
					hVal2 += float3(_ReadVertexDataFromRT( (normBlend.x>0) ? float4(uvz2.zy, level.xx) : float4(-uvz2.z,uvz2.y, level.xx)).PARALLAX_CHANNEL_2ND_LAYER, _ReadVertexDataFromRT( (normBlend.y>0) ? float4(uvz2.xz, level.xx) : float4(-uvz2.x,uvz2.z, level.xx)).PARALLAX_CHANNEL_2ND_LAYER, _ReadVertexDataFromRT( (normBlend.z>0) ? float4(uvz2.yx, level.xx) : float4(-uvz2.y,uvz2.x, level.xx)).PARALLAX_CHANNEL_2ND_LAYER);
				#endif
				hVal += lerp( hVal2, hVal, __VERTEX_COLOR_CHANNEL_LAYER);
			#endif
			hval *= _HeightMapStrength_P3DA;
			*/
		
			blendVal += _TriplanarHeightmapBlendingValue*hVal;
			blendVal /= dot(blendVal,1);
			blendVal*=blendVal;
			blendVal*=blendVal;
			blendVal /= dot(blendVal,1);
			
			#if defined(_TWO_LAYERS)
				// need to call GetH to set height blending between layers
				{
				float2 control=float2(__VERTEX_COLOR_CHANNEL_LAYER, 1-__VERTEX_COLOR_CHANNEL_LAYER);
				float2 hgt=float2(dot(hVal2, blendVal), dot(hVal, blendVal));
				control*=hgt+0.01;			// height evaluation
				control*=control; 			// compress
				control/=dot(control,1);	// normalize
				// no more compression to get smoother cross layer displacement blend
//				control*=control;			// compress
//				control*=control;			// compress
//				control/=dot(control,1);	// normalize
				
				__VERTEX_COLOR_CHANNEL_LAYER=control.x; // write blending value back into the right vertex_color channel variable
				d = lerp(hgt.x, hgt.y, __VERTEX_COLOR_CHANNEL_LAYER);
				}
			#else
				d = dot(hVal, blendVal);
			#endif
			
		#else
			float4 texcoords;
			texcoords.xy=TRANSFORM_TEX(v.uv0, _MainTex);
			texcoords.zw=TRANSFORM_TEX(((_UVSec == 0) ? v.uv0 : v.uv1), _DetailAlbedoMap);
			#if defined(_SNOW)
				d=GetH(vertex_color, texcoords, true, _SnowDeepSmoothen*saturate(_snow_val-0.3)); // true - we're sampling tex2Dlod in per vertex on the _SnowDeepSmoothen*_snow_val level
			#else
				d=GetH(vertex_color, texcoords, true, 0);
			#endif
		#endif
	  
	  #if defined(_SNOW)
			d = saturate( d + saturate(_snow_val-0.7)*0.05*_SnowDeepSmoothen); // TODO - this offset should be calculated a lot more precise (on the surface normal level and in worldspace, because now it's object scale dependent)
	  #endif	  
	  
	  #if defined(DISPLACE_IN_TEXTURE_UNITS)	  
		float approxTan2ObjectRatio=distance(vi[1].vertex, vi[0].vertex) / distance(TRANSFORM_TEX(vi[0].uv0, _MainTex), TRANSFORM_TEX(vi[1].uv0, _MainTex));
	  #else
		float approxTan2ObjectRatio=1;
	  #endif
	  d = d - _TessOffset;
	  #if defined(GEOM_BLEND)
		d = lerp(d, 0, vertex_color.VERTEX_COLOR_CHANNEL_GEOM_BLEND);
	  #endif
	  #if defined(VERTEX_COLOR_CHANNEL_TESELLATION_DISPLACEMENT_AMOUNT)
		d = lerp(0, d, vertex_color.VERTEX_COLOR_CHANNEL_TESELLATION_DISPLACEMENT_AMOUNT);
	  #endif
	  d *= saturate( 1.0 - (distance(_WorldSpaceCameraPos,posWorld) - minDist) / ( (maxDist+minDist)*0.5 - minDist) );
	  
	// displacement
	#endif
	  
	if (_Phong>0) {
		float3 pp[3];
		for (int i = 0; i < 3; ++i)
		pp[i] = v.vertex.xyz - vi[i].normal * (dot(v.vertex.xyz, vi[i].normal) - dot(vi[i].vertex.xyz, vi[i].normal));
		v.vertex.xyz = _Phong * (pp[0]*bary.x + pp[1]*bary.y + pp[2]*bary.z) + (1.0f-_Phong) * v.vertex.xyz;
	}
	
	float customVertexDispl = 0;
	#ifdef _CUSTOM_VERTEX_DISPLACEMENT_
	// asdf
	float2 readuv = (
		//TexCoords(v)
		TexCoordsNoTransform(v)
	/_MainTex_ST.xy - _MainTex_ST.zw)
	*_Atlas_ST_PerMaterial_P3DA.xy + _Atlas_ST_PerMaterial_P3DA.zw
	;
	//float2 readuv = TexCoordsNoTransform(v);
	float4 vertexDisplPaint = _ReadVertexDataFromRT(readuv);//v.uv1
	vertexDisplPaint.rgb = vertexDisplPaint.rgb * 2 - 1;
	//vertexDisplPaint.rgb*=_HeightMapStrength_P3DA*vertexDisplPaint.a;
	/*
	float alphaFlag = frac(floor(vertexDisplPaint.a*10)/10);
	if(alphaFlag == .4)
		customVertexDispl = (vertexDisplPaint.x + vertexDisplPaint.y + vertexDisplPaint.z)/3;
	*/
	#endif

	/*
	#if defined(_CUSTOM_VERTEX_DISPLACEMENT_) && defined(_TESSELLATION_DISPLACEMENT)
	  v.vertex.xyz += v.normal * (d + customVertexDispl) * _TessDepth * approxTan2ObjectRatio;
	#elif defined(_TESSELLATION_DISPLACEMENT)
	  v.vertex.xyz += v.normal * d * _TessDepth * approxTan2ObjectRatio;
	#elif defined(_CUSTOM_VERTEX_DISPLACEMENT_)
	  v.vertex.xyz += v.normal * (d + customVertexDispl)* approxTan2ObjectRatio;	  
	#endif
	*/
	#if defined(_CUSTOM_VERTEX_DISPLACEMENT_) && defined(_TESSELLATION_DISPLACEMENT)
	  if(vertexDisplPaint.a >0.0)
	    v.vertex.xyz += vertexDisplPaint.xyz;
	  v.vertex.xyz += v.normal * (d) * _TessDepth * approxTan2ObjectRatio;
	#elif defined(_TESSELLATION_DISPLACEMENT)
	  v.vertex.xyz += v.normal * d * _TessDepth * approxTan2ObjectRatio;
	#elif defined(_CUSTOM_VERTEX_DISPLACEMENT_)
	  if(vertexDisplPaint.a >0.0)
	    v.vertex.xyz += vertexDisplPaint.xyz;
	  //v.vertex.xyz += v.normal * (d )* approxTan2ObjectRatio;	  
	#endif

	

	  v2f_struct o = VERT_SURF(v);
	  return o;
	}

	// tessellation domain shader
	[UNITY_domain("tri")]
	v2f_struct ds_surf (UnityTessellationFactors tessFactors, const OutputPatch<InternalTessInterp_appdata,3> vi, float3 bary : SV_DomainLocation) {
	  VertexInput v;
	  v.vertex = vi[0].vertex*bary.x + vi[1].vertex*bary.y + vi[2].vertex*bary.z;
	  v.normal = vi[0].normal*bary.x + vi[1].normal*bary.y + vi[2].normal*bary.z;
	  v.uv1 = vi[0].uv1*bary.x + vi[1].uv1*bary.y + vi[2].uv1*bary.z;
	  v.uv2 = vi[0].uv2*bary.x + vi[1].uv2*bary.y + vi[2].uv2*bary.z;
	  v.color = vi[0].color*bary.x + vi[1].color*bary.y + vi[2].color*bary.z;
	  #if !defined(TRIPLANAR_SELECTIVE)
	  v.tangent = vi[0].tangent*bary.x + vi[1].tangent*bary.y + vi[2].tangent*bary.z;
	  v.uv0 = vi[0].uv0*bary.x + vi[1].uv0*bary.y + vi[2].uv0*bary.z;
	  #endif
	  UNITY_TRANSFER_INSTANCE_ID(vi[0], v); // all vi[n] has the same instanceID transferred

	  //
	  // compute displacement
	  //
	  #if defined(_TESSELLATION_DISPLACEMENT)
		fixed4 vertex_color=v.color;
		float3 normalWorld = UnityObjectToWorldNormal(v.normal);
		
		float4 posWorld = mul(unity_ObjectToWorld, v.vertex);
		
		#if defined(_SNOW)
			float _snow_val = _SnowColorAndCoverage.a*__VERTEX_COLOR_CHANNEL_SNOW;
			_snow_val *= saturate((posWorld.y-_SnowHeightThreshold)/_SnowHeightThresholdTransition);
			_snow_val = saturate( _snow_val - (1-normalWorld.y)*_SnowSlopeDamp );
			_snow_val *= _SnowLevelFromGlobal ? (1-_UBER_GlobalSnowDamp) : 1;
		#endif
	  
		float d=0; // displacement value
		#if defined(TRIPLANAR_SELECTIVE)
			#if defined(_TRIPLANAR_WORLD_MAPPING)
				float3 normBlend=normalWorld;
				float3 posUVZ=posWorld.xyz;
				float3 blendVal = abs(normBlend);
			#else
				float scaleX = length(float3(unity_ObjectToWorld[0][0], unity_ObjectToWorld[1][0], unity_ObjectToWorld[2][0]));
				float scaleY = length(float3(unity_ObjectToWorld[0][1], unity_ObjectToWorld[1][1], unity_ObjectToWorld[2][1]));
				float scaleZ = length(float3(unity_ObjectToWorld[0][2], unity_ObjectToWorld[1][2], unity_ObjectToWorld[2][2]));
				
				float3 objScale=float3(scaleX, scaleY, scaleZ);
				float3 normObj=v.normal;
				float3 normBlend=normObj;
				float3 normObjScaled=normalize(normObj/objScale);
				float3 posUVZ=v.vertex.xyz*objScale;
				float3 blendVal = abs(normObjScaled);
			#endif	
			
			#if defined(_SNOW)
				float level=_SnowDeepSmoothen*saturate(_snow_val-0.3);
			#else
				float level=0;
			#endif
						
			float3 uvz = posUVZ.xyz*_MainTex_ST.xxx;
			float3 hVal = float3(tex2Dlod(_ParallaxMap, (normBlend.x>0) ? float4(uvz.zy, level.xx) : float4(-uvz.z,uvz.y, level.xx)).PARALLAX_CHANNEL, tex2Dlod(_ParallaxMap, (normBlend.y>0) ? float4(uvz.xz, level.xx) : float4(-uvz.x,uvz.z, level.xx)).PARALLAX_CHANNEL, tex2Dlod(_ParallaxMap, (normBlend.z>0) ? float4(uvz.yx, level.xx) : float4(-uvz.y,uvz.x, level.xx)).PARALLAX_CHANNEL);
			#if defined(_TWO_LAYERS)
				float3 uvz2 = posUVZ.xyz*_DetailAlbedoMap_ST.xxx;
				#if defined(_PARALLAXMAP_2MAPS)
					float3 hVal2 = float3(tex2Dlod(_ParallaxMap2, (normBlend.x>0) ? float4(uvz2.zy, level.xx) : float4(-uvz2.z,uvz2.y, level.xx)).PARALLAX_CHANNEL, tex2Dlod(_ParallaxMap2, (normBlend.y>0) ? float4(uvz2.xz, level.xx) : float4(-uvz2.x,uvz2.z, level.xx)).PARALLAX_CHANNEL, tex2Dlod(_ParallaxMap2, (normBlend.z>0) ? float4(uvz2.yx, level.xx) : float4(-uvz2.y,uvz2.x, level.xx)).PARALLAX_CHANNEL);
				#else
					float3 hVal2 = float3(tex2Dlod(_ParallaxMap2, (normBlend.x>0) ? float4(uvz2.zy, level.xx) : float4(-uvz2.z,uvz2.y, level.xx)).PARALLAX_CHANNEL_2ND_LAYER, tex2Dlod(_ParallaxMap2, (normBlend.y>0) ? float4(uvz2.xz, level.xx) : float4(-uvz2.x,uvz2.z, level.xx)).PARALLAX_CHANNEL_2ND_LAYER, tex2Dlod(_ParallaxMap2, (normBlend.z>0) ? float4(uvz2.yx, level.xx) : float4(-uvz2.y,uvz2.x, level.xx)).PARALLAX_CHANNEL_2ND_LAYER);
				#endif
				hVal = lerp( hVal2, hVal, __VERTEX_COLOR_CHANNEL_LAYER);
			#endif
			
			blendVal += _TriplanarHeightmapBlendingValue*hVal;
			blendVal /= dot(blendVal,1);
			blendVal*=blendVal;
			blendVal*=blendVal;
			blendVal /= dot(blendVal,1);
			
			#if defined(_TWO_LAYERS)
				// need to call GetH to set height blending between layers
				{
				float2 control=float2(__VERTEX_COLOR_CHANNEL_LAYER, 1-__VERTEX_COLOR_CHANNEL_LAYER);
				float2 hgt=float2(dot(hVal2, blendVal), dot(hVal, blendVal));
				control*=hgt+0.01;			// height evaluation
				control*=control; 			// compress
				control/=dot(control,1);	// normalize
				// no more compression to get smoother cross layer displacement blend
//				control*=control;			// compress
//				control*=control;			// compress
//				control/=dot(control,1);	// normalize
				
				__VERTEX_COLOR_CHANNEL_LAYER=control.x; // write blending value back into the right vertex_color channel variable
				d = lerp(hgt.x, hgt.y, __VERTEX_COLOR_CHANNEL_LAYER);
				}
			#else
				d = dot(hVal, blendVal);
			#endif
			
		#else
			float4 texcoords;
			texcoords.xy=TRANSFORM_TEX(v.uv0, _MainTex);
			texcoords.zw=TRANSFORM_TEX(((_UVSec == 0) ? v.uv0 : v.uv1), _DetailAlbedoMap);
			#if defined(_SNOW)
				d=GetH(vertex_color, texcoords, true, _SnowDeepSmoothen*saturate(_snow_val-0.3)); // true - we're sampling tex2Dlod in per vertex on the _SnowDeepSmoothen*_snow_val level
			#else
				d=GetH(vertex_color, texcoords, true, 0);
			#endif
		#endif
	  
	  #if defined(_SNOW)
			d = saturate( d + saturate(_snow_val-0.7)*0.05*_SnowDeepSmoothen); // TODO - this offset should be calculated a lot more precise (on the surface normal level and in worldspace, because now it's object scale dependent)
	  #endif	  
	  
	  #if defined(DISPLACE_IN_TEXTURE_UNITS)	  
		float approxTan2ObjectRatio=distance(vi[1].vertex, vi[0].vertex) / distance(TRANSFORM_TEX(vi[0].uv0, _MainTex), TRANSFORM_TEX(vi[1].uv0, _MainTex));
	  #else
		float approxTan2ObjectRatio=1;
	  #endif
	  d = d - _TessOffset;
	  #if defined(GEOM_BLEND)
		d = lerp(d, 0, vertex_color.VERTEX_COLOR_CHANNEL_GEOM_BLEND);
	  #endif
	  #if defined(VERTEX_COLOR_CHANNEL_TESELLATION_DISPLACEMENT_AMOUNT)
		d = lerp(0, d, vertex_color.VERTEX_COLOR_CHANNEL_TESELLATION_DISPLACEMENT_AMOUNT);
	  #endif
	  d *= saturate( 1.0 - (distance(_WorldSpaceCameraPos,posWorld) - minDist) / ( (maxDist+minDist)*0.5 - minDist) );
	  
	// displacement
	#endif
	  
	if (_Phong>0) {
		float3 pp[3];
		for (int i = 0; i < 3; ++i)
		pp[i] = v.vertex.xyz - vi[i].normal * (dot(v.vertex.xyz, vi[i].normal) - dot(vi[i].vertex.xyz, vi[i].normal));
		v.vertex.xyz = _Phong * (pp[0]*bary.x + pp[1]*bary.y + pp[2]*bary.z) + (1.0f-_Phong) * v.vertex.xyz;
	}
			
	#if defined(_TESSELLATION_DISPLACEMENT)
	  v.vertex.xyz += v.normal * d * _TessDepth * approxTan2ObjectRatio;
	#endif
	  
	  v2f_struct o = VERT_SURF(v);
	  return o;
	}

#endif // TESSELLATION

//============================= META ==============================
#if UNITY_PASS_META
struct v2f_meta
{
	UNITY_POSITION(pos);
	float4 tex							: TEXCOORD0; // normal in triplanar
	float4 tangentToWorldAndParallax0	: TEXCOORD1;	// [3x3:tangentToWorld | 1x3:viewDirForParallax] - note: tangents+obj scale in triplanar (tangents in world space when mapping in world space)
	float4 tangentToWorldAndParallax1	: TEXCOORD2;	// (array fails in GLSL optimizer)
	float4 tangentToWorldAndParallax2	: TEXCOORD3;
	float3 eyeVec						: TEXCOORD4;
	fixed4 vertex_color					: COLOR0;
	#if defined(TRIPLANAR_SELECTIVE) && !defined(_TRIPLANAR_WORLD_MAPPING)
	float3 posObject					: TEXCOORD5;
	#endif	
	#ifdef UNITY_REQUIRE_FRAG_WORLDPOS
		float3 posWorld					: TEXCOORD6;
	#endif	

#if defined(VERTEX_COLOR_RGB_TO_ALBEDO_INDEXED)
		float3 diffuseTint					: TEXCOORD7;
#elif defined(VERTEX_COLOR_RGB_TO_ALBEDO_DOUBLE_INDEXED)
		float3 diffuseTint					: TEXCOORD7;
		float3 diffuseTint2					: TEXCOORD8;
#endif

};

v2f_meta vert_meta (VertexInput v)
{
	v2f_meta o;
	UNITY_INITIALIZE_OUTPUT(v2f_meta, o);


	// input v.vertex is actually used for nothing now, but openGL needs such implicit input ?
	o.pos = UnityMetaVertexPosition(v.vertex, v.uv1.xy, v.uv2.xy, unity_LightmapST, unity_DynamicLightmapST);
	
	#if defined(TRIPLANAR_SELECTIVE) && !defined(_TRIPLANAR_WORLD_MAPPING)
		o.posObject.xyz = v.vertex.xyz;
	#endif
	
	float4 posWorld = mul(unity_ObjectToWorld, v.vertex);
	#ifdef UNITY_REQUIRE_FRAG_WORLDPOS
		o.posWorld.xyz = posWorld.xyz;
	#endif
	o.vertex_color = v.color;
	o.eyeVec = normalize(posWorld.xyz - _WorldSpaceCameraPos);	
	
	#if !defined(TRIPLANAR_SELECTIVE)
		//float3 normalWorld = UnityObjectToWorldNormal(v.normal); // FIXME - for unknown reason normalWorld isn't actually computed here (either _World2Object, _Object2World or v.vnormal has incorrect values here)
		float3 normalWorld = UnityObjectToWorldDir(v.normal.xyz); // still can't tell if this is any better...
	#endif
	
	#if defined(TRIPLANAR_SELECTIVE)
		#if defined(_TRIPLANAR_WORLD_MAPPING)
			float3 normalWorld = UnityObjectToWorldDir(v.normal.xyz);
			SetupUBER_VertexData_TriplanarWorld(normalWorld, /* inout */ o.tangentToWorldAndParallax0, /* inout */ o.tangentToWorldAndParallax1, /* inout */ o.tangentToWorldAndParallax2);
		#else
			float scaleX, scaleY, scaleZ;
			SetupUBER_VertexData_TriplanarLocal(v.normal, /* inout */ o.tangentToWorldAndParallax0, /* inout */ o.tangentToWorldAndParallax1, /* inout */ o.tangentToWorldAndParallax2, /* out */ scaleX, /* out */ scaleY, /* out */ scaleZ);
			o.posObject.xyz = v.vertex.xyz;
		#endif		
	#elif defined(_TANGENT_TO_WORLD)	
		float4 tangentWorld = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);

		float3x3 tangentToWorld = CreateTangentToWorldPerVertex(normalWorld, tangentWorld.xyz, tangentWorld.w);
		o.tangentToWorldAndParallax0.xyz = tangentToWorld[0];
		o.tangentToWorldAndParallax1.xyz = tangentToWorld[1];
		o.tangentToWorldAndParallax2.xyz = tangentToWorld[2];
	#else
		o.tangentToWorldAndParallax0.xyz = 0;
		o.tangentToWorldAndParallax1.xyz = 0;
		o.tangentToWorldAndParallax2.xyz = normalWorld;
	#endif	
	
	#if defined(TRIPLANAR_SELECTIVE)
		#if defined(_TRIPLANAR_WORLD_MAPPING)
			// .w component not used
		#else
			o.tangentToWorldAndParallax0.w=scaleX;
			o.tangentToWorldAndParallax1.w=scaleY;
			o.tangentToWorldAndParallax2.w=scaleZ;
		#endif
	#endif
		
	#if defined(TRIPLANAR_SELECTIVE)
		#if defined(_TRIPLANAR_WORLD_MAPPING)
			o.tex = float4(normalWorld,0);
			// o.tangentToWorldAndParallax[n].w component not used
		#else
			o.tex = float4(v.normal,0);
			o.tangentToWorldAndParallax0.w=scaleX;
			o.tangentToWorldAndParallax1.w=scaleY;
			o.tangentToWorldAndParallax2.w=scaleZ;
		#endif
	#else
		o.tex = TexCoords(v);
	#endif	

#if defined(VERTEX_COLOR_RGB_TO_ALBEDO_INDEXED)
		uint idx = uint(clamp(floor(v.color.VERTEX_COLOR_RGB_TO_ALBEDO_INDEXED * 255), 0, 15));
		o.diffuseTint = diffuseTintArray[idx];
#elif defined(VERTEX_COLOR_RGB_TO_ALBEDO_DOUBLE_INDEXED)
		uint idx = uint(clamp(frac(v.color.VERTEX_COLOR_RGB_TO_ALBEDO_DOUBLE_INDEXED * 16) * 16, 0, 15));
		o.diffuseTint = diffuseTintArray[idx];
		idx = uint(clamp(floor(v.color.VERTEX_COLOR_RGB_TO_ALBEDO_DOUBLE_INDEXED * 16), 0, 15));
		o.diffuseTint2 = diffuseTintArrayB[idx];
#endif

	return o;
}

// Albedo for lightmapping should basically be diffuse color.
// But rough metals (black diffuse) still scatter quite a lot of light around, so
// we want to take some of that into account too.
float3 UnityLightmappingAlbedo (float3 diffuse, float3 specular, float smoothness)
{
	float roughness = 1 - smoothness;
	float3 res = diffuse;
	res += specular * roughness * roughness * 0.5;
	return res;
}

float4 frag_meta (v2f_meta i
#if defined(_2SIDED)
,float facing : VFACE
#endif
) : SV_Target
{
	#if defined(_2SIDED)
		#if UNITY_VFACE_FLIPPED
			facing = -facing;
		#endif
		#if UNITY_VFACE_AFFECTED_BY_PROJECTION
			facing *= _ProjectionParams.x; // take possible upside down rendering into account
		#endif	
		#if defined(TRIPLANAR_SELECTIVE)
			i.tex.xyz *= facing>0 ? 1 : -1;
		#else
			i.tangentToWorldAndParallax2 *= facing>0 ? 1 : -1;
		#endif
	#endif
	
	#ifdef UNITY_REQUIRE_FRAG_WORLDPOS
		float3 posWorld=i.posWorld.xyz;
	#else
		float3 posWorld=0;
	#endif
	
	float actH;
	float4 SclCurv;
	float3 eyeVec;
	
	float3 tangentBasisScaled;
	
	float2 _ddx;
	float2 _ddy;
	float2 _ddxDet;
	float2 _ddyDet;
	float blendFade;
	
	float3 i_viewDirForParallax;
	float3x3 _TBN;
	float3 worldNormal;
	
	float4 texcoordsNoTransform;
	
	// void	SetupUBER(float4 i_SclCurv, float3 i_eyeVec, float3 i_posWorld, float3 i_posObject, inout float4 i_tex, inout float4 i_tangentToWorldAndParallax0, inout float4 i_tangentToWorldAndParallax1, inout float4 i_tangentToWorldAndParallax2, inout fixed4 vertex_color, out float actH, out float4 SclCurv, out float3 eyeVec, out float3 tangentBasisScaled, out float2 _ddx, out float2 _ddy, out float2 _ddxDet, out float2 _ddyDet, out float blendFade, out float3 i_viewDirForParallax, out float3x3 _TBN, out float3 worldNormal) {
	#if defined(TRIPLANAR_SELECTIVE) && !defined(_TRIPLANAR_WORLD_MAPPING)
		SetupUBER(float4(0,0,0,0), float3(0,0,0), posWorld, i.posObject.xyz, /* inout */ i.tex, /* inout */ i.tangentToWorldAndParallax0, /* inout */ i.tangentToWorldAndParallax1, /* inout */ i.tangentToWorldAndParallax2, /* inout */ i.vertex_color, /* out */ actH, /* out */ SclCurv, /* out */ eyeVec, /* out */ tangentBasisScaled, /* out */ _ddx, /* out */ _ddy, /* out */ _ddxDet, /* out */ _ddyDet, /* out */ blendFade, /* out */ i_viewDirForParallax, /* out */ _TBN, /* out */ worldNormal, /* out */ texcoordsNoTransform);
	#else
		SetupUBER(float4(0,0,0,0), float3(0,0,0), posWorld, float3(0,0,0), /* inout */ i.tex, /* inout */ i.tangentToWorldAndParallax0, /* inout */ i.tangentToWorldAndParallax1, /* inout */ i.tangentToWorldAndParallax2, /* inout */ i.vertex_color, /* out */ actH, /* out */ SclCurv, /* out */ eyeVec, /* out */ tangentBasisScaled, /* out */ _ddx, /* out */ _ddy, /* out */ _ddxDet, /* out */ _ddyDet, /* out */ blendFade, /* out */ i_viewDirForParallax, /* out */ _TBN, /* out */ worldNormal, /* out */ texcoordsNoTransform);
	#endif
	// ------	
	
	// inline FragmentCommonData FragmentSetup (inout float4 i_tex, float3 i_eyeVec, float3 i_normalWorld, inout float3 i_viewDirForParallax, inout float3x3 i_tanToWorld, float3 i_posWorld, inout fixed4 vertex_color, float2 _ddx, float2 _ddy, float2 _ddxDet, float2 _ddyDet, float3 tangentBasisScaled, float4 SclCurv, float blendFade, float actH) // UBER - additional params added
//	FragmentSetup(i.tex, eyeVec, worldNormal, i_viewDirForParallax, _TBN, IN_WORLDPOS(i), i.vertex_color, _ddx, _ddy, _ddxDet, _ddyDet, tangentBasisScaled, SclCurv, blendFade, actH, diffuseTint, diffuseTint2); // UBER - additional params added
#if defined(VERTEX_COLOR_RGB_TO_ALBEDO_INDEXED)
		float3 diffuseTint = i.diffuseTint;
		float3 diffuseTint2 = float3(0.5, 0.5, 0.5);
#elif defined(VERTEX_COLOR_RGB_TO_ALBEDO_DOUBLE_INDEXED)
		float3 diffuseTint = i.diffuseTint;
		float3 diffuseTint2 = i.diffuseTint2;
#else
		float3 diffuseTint = float3(0.5, 0.5, 0.5);
		float3 diffuseTint2 = float3(0.5, 0.5, 0.5);
#endif
	FragmentCommonData s = FragmentSetup(i.tex, float3(0,0,0), worldNormal, i_viewDirForParallax, _TBN, posWorld, i.vertex_color, _ddx, _ddy, _ddxDet, _ddyDet, tangentBasisScaled, SclCurv, 1, actH, diffuseTint, diffuseTint2);
	#if defined(_SNOW)
		float snowBlur=_SnowDeepSmoothen*4*s.snowVal; // currently not used
		float3 snowEmissionDamp=LerpWhiteTo(_SnowEmissionTransparency, s.snowVal);
	#else
		float snowBlur=0; // not used
		float3 snowEmissionDamp=1;
	#endif

	#if defined(EMISSION_AT_THE_OTHER_SIDE)
		snowEmissionDamp *= saturate(dot(-i.tangentToWorldAndParallax2, DeferredLightDir(i.posWorld.xyz))*4);
	#endif
	
	UnityMetaInput o;
	UNITY_INITIALIZE_OUTPUT(UnityMetaInput, o);

	o.Albedo = UnityLightmappingAlbedo (s.diffColor, s.specColor, s.smoothness);
	o.Emission = Emission(i.tex.xyzw, i.vertex_color, _ddx, _ddy, snowBlur)*snowEmissionDamp; // UBER - 4 components (main uv, detail uv) + vertex color (for masking), under snow blurring
	o.Emission += s.additionalEmission*snowEmissionDamp; // UBER - detail/wet emission
	return UnityMetaFragment(o);
}
#endif // META
//============================= META ==============================

#endif // UBER_STANDARD_CORE_INCLUDED
