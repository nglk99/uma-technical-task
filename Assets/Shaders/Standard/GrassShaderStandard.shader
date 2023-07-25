Shader "Custom/GrassShaderStandard"
//Author: Angelika Vartanyan
{
	Properties
	{
		//Setting up parameters
		[Header(Tint Colors)]
		[Space]
		[MainColor] _Color("Tint Color",Color) = (0.5 ,0.5 ,0.5,1.0)
		_SelfShadowColor("Shadow Color",Color) = (0.41 ,0.41 ,0.36,1.0)
		_GrassSaturation("Grass Saturation", Float) = 2

		[Header(Textures)]
		[Space]
		[MainTexture]_MainTex("Color Grass", 2D) = "white" {}
		[NoScaleOffset]_GrassTex("Grass Pattern", 2D) = "white" {}
		[NoScaleOffset]_Noise("Noise Color", 2D) = "white" {}
		[NoScaleOffset]_Distortion("Distortion Wind", 2D) = "white" {}

		[Header(Geometry Values)]
		[Space]
		_MinimumNumberStacks("Min Displacement", Range(0, 17)) = 2
		_NumberOfStacks("Displacement", Range(0, 17)) = 12
		_OffsetValue("Offset Normal", Float) = 1
		_OffsetVector("Offset Vector", Vector) = (0,0,0)

		[Header(Grass Values)]
		[Space]
		_GrassThinness("Grass Thinness", Range(0.01, 2)) = 0.4
		_GrassThinnessIntersection("Grass Thinness Intersection", Range(0.01, 2)) = 0.43
		_TilingN1("Tiling Of Grass", Float) = 6.06
		_WindMovement("Wind Movement Speed", Float) = 0.55
		_WindForce("Wind Force", Float) = 0.35
		_TilingN3("Wind Noise Tiling", Float) = 1
		_NoisePower("Noise Power", Float) = 2
		_TilingN2("Tiling Of Noise Color", Float) = 0.05

		[Header(Level of Detail)]
		[Space]
		_FadeDistanceStart("LOD Fade-Distance Start", Float) = 16
		_FadeDistanceEnd("LOD Fade-Distance End", Float) = 26
	}
		SubShader
		{
			Tags{"DisableBatching" = "true" }
			pass
			{
			Tags{ "LightMode" = "ForwardBase"}
			LOD 200
			ZWrite true
			CGPROGRAM

			#pragma target 4.5
			#pragma require geometry
				// excluded shader from OpenGL ES 2.0 because it uses non-square matrices, if you need it to work on ES 2.0 comment the line below
				#pragma exclude_renderers gles

				#pragma vertex vert
				#pragma fragment frag
				#pragma geometry geom
				#pragma multi_compile_fog
				#pragma multi_compile_fwdbase

				//#define SHADOWS_SCREEN
				#include "AutoLight.cginc"
				//#include "Lighting.cginc"
				#include "UnityCG.cginc"
				#pragma multi_compile _ LIGHTMAP_ON

					uniform float4 _LightColor0;
					uniform sampler2D _LightTexture0;

					struct appdata
					{
						float4 vertex : POSITION;
						float2 uv : TEXCOORD0;
						float4 normal : NORMAL;
					};

					struct v2g
					{
						float2 uv : TEXCOORD0;
						float4 pos : SV_POSITION;
						float4 objPos : TEXCOORD1;
						float3 normal : TEXCOORD2;
						SHADOW_COORDS(4)
						UNITY_FOG_COORDS(5)

					};

					struct g2f
					{
						float2 uv : TEXCOORD0;
						float4 pos : SV_POSITION;
						float3 worldPos : TEXCOORD1;
						float2 color : COLOR;
						float3 normal : TEXCOORD2;
						SHADOW_COORDS(3)
						UNITY_FOG_COORDS(4)
					};

					struct SHADOW_VERTEX // This is needed for custom shadow casting
					{
						float4 vertex : POSITION;
					};

					int _NumberOfStacks, _MinimumNumberStacks;
					Texture2D _MainTex;
					float4 _MainTex_ST;
					Texture2D _Distortion;
					sampler2D _GrassTex;
					Texture2D _Noise;
					float _TilingN1;
					float _TilingN2, _WindForce;
					float4 _Color, _SelfShadowColor, _ProjectedShadowColor;
					float4 _OffsetVector;
					float _TilingN3;
					float _WindMovement, _OffsetValue;
					half _GrassThinness, _GrassThinnessIntersection;
					half _NoisePower, _GrassSaturation, _FadeDistanceStart, _FadeDistanceEnd;
					float _ProceduralDistance, _ProceduralStrength;
					SamplerState my_linear_repeat_sampler;
					SamplerState my_linear_clamp_sampler;

					//Stochastic sampling
					float2 hash2D2D(float2 s)
					{
						return frac(sin(s) * 4.5453);
					}
					
					float4 tex2DStochastic(sampler2D tex, float2 UV)
					{
						float4x3 BW_vx;
						float2 skewUV = mul(float2x2 (1.0, 0.0, -0.57735027, 1.15470054), UV * 3.464);

						//Setting up vertex IDs and barycentric coords
						float2 vxID = float2 (floor(skewUV));
						float3 barry = float3 (frac(skewUV), 0);
						barry.z = 1.0 - barry.x - barry.y;

						BW_vx = ((barry.z > 0) ?
							float4x3(float3(vxID, 0), float3(vxID + float2(0, 1), 0), float3(vxID + float2(1, 0), 0), barry.zyx) :
							float4x3(float3(vxID + float2 (1, 1), 0), float3(vxID + float2 (1, 0), 0), float3(vxID + float2 (0, 1), 0), float3(-barry.z, 1.0 - barry.y, 1.0 - barry.x)));

						//Calculate derivatives to avoid triangular grid artifacts
						float2 dx = ddx(UV);
						float2 dy = ddy(UV);

						float4 stochasticTex = mul(tex2D(tex, UV + hash2D2D(BW_vx[0].xy), dx, dy), BW_vx[3].x) +
							mul(tex2D(tex, UV + hash2D2D(BW_vx[1].xy), dx, dy), BW_vx[3].y) +
							mul(tex2D(tex, UV + hash2D2D(BW_vx[2].xy), dx, dy), BW_vx[3].z);
						return stochasticTex;
					}

					v2g vert(appdata v)
					{
						v2g o;
						o.objPos = v.vertex;
						o.pos = UnityObjectToClipPos(v.vertex);
						o.uv = TRANSFORM_TEX(v.uv, _MainTex);
	#ifdef SHADOWS_SCREEN
						o._ShadowCoord = ComputeScreenPos(o.pos);
	#endif
						o.normal = v.normal;
						UNITY_TRANSFER_FOG(o, o.pos);
						return o;
					}

					#define UnityObjectToWorld(o) mul(unity_ObjectToWorld, float4(o.xyz,1.0))
					[instance(1)]
					[maxvertexcount(51)]
					//Creating additional geometry
					void geom(triangle v2g input[3], uint InstanceID : SV_GSInstanceID, inout TriangleStream<g2f> tristream)
					{
						g2f o;
						SHADOW_VERTEX v;
						_OffsetValue *= 0.01;

						float numInstance = 1;
						// Loop 3 times for the base ground geometry
						for (int j = 0; j < 3; j++)
						{
							o.uv = input[j].uv;
							o.pos = input[j].pos;

							o.color = 0.0;
							o.normal = normalize(mul(float4(input[j].normal, 0.0), unity_WorldToObject).xyz);
							o.worldPos = UnityObjectToWorld(input[j].objPos);
	#ifdef SHADOWS_SCREEN
							o._ShadowCoord = input[j]._ShadowCoord;
	#endif
							UNITY_TRANSFER_FOG(o, o.pos);
							tristream.Append(o);
						}
						tristream.RestartStrip();

						//LOD Distance calculation
						//limits the geometry where it is not necessary
						float dist = distance(_WorldSpaceCameraPos, UnityObjectToWorld((input[0].objPos / 3 + input[1].objPos / 3 + input[2].objPos / 3)));
						if (dist > 0)
						{
							int NumStacks = lerp(_NumberOfStacks + 1, 0, (dist - _FadeDistanceStart) * (1 / max(_FadeDistanceEnd - _FadeDistanceStart, 0.0001)));//Clamp 
							_NumberOfStacks = min(clamp(NumStacks, clamp(_MinimumNumberStacks, 0, _NumberOfStacks), 17), _NumberOfStacks);
						}

						float4 P; // P is shadow coords new position
						float4 objSpace; // objSpace is the vertex new position
						float4 offsetNormalI = (_OffsetVector / numInstance * 0.01) * (InstanceID + 1);
						float thicknessModifier = 1;

						// Loop 3 times * numbersOfStacks for the grass
						// Calculate shadows
							for (float i = 1; i <= _NumberOfStacks; i++)
							{
								//Adding the custom offset to the normal
								float4 offsetNormal = _OffsetVector * i * 0.01;
								for (int ii = 0; ii < 3; ii++)
								{
									float4 NewNormal = float4(normalize(input[ii].normal) * _OffsetValue, 0);
	#ifdef SHADOWS_SCREEN
									P = input[ii]._ShadowCoord;
	#else
									P = 1;
	#endif
									objSpace = float4(input[ii].objPos + NewNormal * thicknessModifier * i + offsetNormal * thicknessModifier - (NewNormal * thicknessModifier / numInstance) * (InstanceID + 1) - offsetNormalI * thicknessModifier);

									o.color = (i /_NumberOfStacks) - ((1 * InstanceID) / (_NumberOfStacks * numInstance));
									o.uv = input[ii].uv;
									o.pos = UnityObjectToClipPos(objSpace);
	#ifdef SHADOWS_SCREEN
									o._ShadowCoord = P;
	#endif
									o.worldPos = UnityObjectToWorld(objSpace);
									o.normal = normalize(mul(float4(input[ii].normal, 0.0), unity_WorldToObject).xyz);
									UNITY_TRANSFER_FOG(o, o.pos);
									tristream.Append(o);
								}
								tristream.RestartStrip();
						}
					}
					half4 frag(g2f i) : SV_Target
					{
					//Calculate Distance to camera
					float dist = 1;
					float2 mainUV;
					//Setup Coordinate Space
					mainUV = i.uv;
					float2 uv = i.worldPos.xz;
					uv += 0.5;

					//Creating the Wind Distortion
					float bRipple = 1;

					float2 dis = _Distortion.Sample(my_linear_repeat_sampler, mainUV * _TilingN3 + _Time.xx * 3 * _WindMovement);
					float displacementStrengh = 0.6 * (((sin(_Time.y + dis * 5) + sin(_Time.y * 0.5 + 1.051)) / 5.0) + 0.15 * dis) * bRipple; 
					dis = dis * displacementStrengh * (i.color.r * 1.3) * _WindForce * bRipple;

					float ripples = 0.25;
					float ripples2 = 0;
					float ripples3 = 0;

					//Multi-texture tiling 
					float3 normalDir = i.normal;
					float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);
					float3 grassPattern = tex2D(_GrassTex, mainUV * _TilingN1 + dis.xy);
					float3 noise = _Noise.Sample(my_linear_repeat_sampler, mainUV * _TilingN2 + dis.xy) * _NoisePower;
					half4 col = _MainTex.Sample(my_linear_repeat_sampler, mainUV + dis.xy * 0.09);
					
					//Adding distortion
					half alpha = step(1 - ((col.x + col.y + col.z + grassPattern.x) * _GrassThinness) * ((2 - i.color.r) * grassPattern.x) * saturate(ripples + 1) * saturate(ripples + 1), ((1 - i.color.r) * (ripples + 1)) * (grassPattern.x) * _GrassThinness - dis.x * 5);
					alpha = lerp(alpha, alpha + (grassPattern.x * (1 - i.color.r)) * _GrassThinnessIntersection, 1 * (ripples + 0.75));

					if (i.color.r >= 0.02)
					{
						if (alpha * (ripples3 + 1) - (i.color.r) < -0.02)discard;
					}
					//Color distortion
					_Color *= 2;
					col.xyz = (pow(col, _GrassSaturation) * _GrassSaturation) * float3(_Color.x, _Color.y, _Color.z);
					col.xyz *= saturate(lerp(_SelfShadowColor, 1, pow(i.color.x, 1.1)) + ((ripples * 1 + 1) - noise.x * dis.x * 2) + 1 - noise.x * dis.x * 2);
					col.xyz *= _Color * (ripples * -0.1 + 1);
					col.xyz *= 1 - (ripples2 * (1 - saturate(i.color.r - 0.7)));

					UNITY_APPLY_FOG(i.fogCoord, col);
					return col;
				}
				ENDCG
			}
		// SHADOW CASTING PASS, this will redraw geometry so keep this pass disabled if you want to save performance
		// Keep it if you want depth for post process or if you're using deferred rendering
		Pass{
				Tags {"LightMode" = "ShadowCaster"}

			CGPROGRAM
			#pragma target 4.5
			#pragma require geometry
			#pragma vertex vert
			#pragma fragment frag
			#pragma geometry geom
			#include "UnityCG.cginc"

		struct appdata
		{
			float4 vertex : POSITION;
			float2 uv : TEXCOORD0;
			float4 normal : NORMAL;
		};

		struct v2g
		{
			float2 uv : TEXCOORD0;
			float4 pos : SV_POSITION;
			float4 objPos : TEXCOORD1;
			float3 normal : TEXCOORD3;
		};

		struct g2f
		{
			float2 uv : TEXCOORD0;
			float3 worldPos : TEXCOORD1;
			float3 normal : TEXCOORD2;
			float2 color : COLOR;
			V2F_SHADOW_CASTER;
		};

		struct SHADOW_VERTEX
		{
			float4 vertex : POSITION;
		};

			Texture2D _MainTex;
			Texture2D _Noise;

			int _NumberOfStacks, _MinimumNumberStacks;
			float4 _MainTex_ST;
			Texture2D _Distortion;
			Texture2D _GrassTex;
			float _TilingN1;
			float _WindForce, _TilingN2;
			float4 _OffsetVector;
			float _TilingN3;
			float _WindMovement, _OffsetValue, _FadeDistanceStart, _FadeDistanceEnd;
			half _GrassThinness, _GrassThinnessIntersection, _NoisePower;
			SamplerState my_linear_repeat_sampler;
			SamplerState my_linear_clamp_sampler;

					v2g vert(appdata v)
					{
						v2g o;

						o.objPos = v.vertex;
						o.pos = UnityObjectToClipPos(v.vertex);
						o.normal = v.normal;
						TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
						o.uv = TRANSFORM_TEX(v.uv, _MainTex);
						return o;
					}

					#define UnityObjectToWorld(o) mul(unity_ObjectToWorld, float4(o.xyz,1.0))
					[instance(1)]
					[maxvertexcount(51)]
					void geom(triangle v2g input[3], uint InstanceID : SV_GSInstanceID, inout TriangleStream<g2f> tristream) {

						g2f o;

						SHADOW_VERTEX v;
						_OffsetValue *= 0.01;
						float numInstance = 1;

						for (int j = 0; j < 3; j++)
						{
							o.uv = input[j].uv;
							o.pos = input[j].pos;

							o.color = 0.0;
							o.normal = normalize(mul(float4(input[j].normal, 0.0), unity_WorldToObject).xyz);
							o.worldPos = UnityObjectToWorld(input[j].objPos);

							tristream.Append(o);
						}
					}

			float4 frag(g2f i) : SV_Target
			{
				float2 mainUV;

			//Setup Coordinate Space
				mainUV = i.uv;
				SHADOW_CASTER_FRAGMENT(i)
					}
					ENDCG
				}
		}
}
