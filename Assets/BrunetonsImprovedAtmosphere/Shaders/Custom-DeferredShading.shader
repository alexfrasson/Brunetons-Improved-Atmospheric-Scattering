// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader "Hidden/Custom-DeferredShading" {
	Properties{
		_LightTexture0("", any) = "" {}
		_LightTextureB0("", 2D) = "" {}
		_ShadowMapTexture("", any) = "" {}
		_SrcBlend("", Float) = 1
		_DstBlend("", Float) = 1
	}
		SubShader{

			// Pass 1: Lighting pass
			//  LDR case - Lighting encoded into a subtractive ARGB8 buffer
			//  HDR case - Lighting additively blended into floating point buffer
			Pass {
				ZWrite Off
				Blend[_SrcBlend][_DstBlend]

			CGPROGRAM
			#pragma target 3.0
			#pragma vertex vert_deferred
			#pragma fragment frag
			#pragma multi_compile_lightpass
			#pragma multi_compile ___ UNITY_HDR_ON
			#pragma multi_compile __ RADIANCE_API_ENABLED

			#pragma exclude_renderers nomrt

			#include "UnityCG.cginc"
			#include "UnityDeferredLibrary.cginc"
			#include "UnityPBSLighting.cginc"
			#include "UnityStandardUtils.cginc"
			#include "UnityGBuffer.cginc"
			#include "UnityStandardBRDF.cginc"

			sampler2D _CameraGBufferTexture0;
			sampler2D _CameraGBufferTexture1;
			sampler2D _CameraGBufferTexture2;

			//--------------------------------------------------------------------------------------------------------------
			#include "Definitions.cginc"
			#include "UtilityFunctions.cginc"
			#include "TransmittanceFunctions.cginc"
			#include "ScatteringFunctions.cginc"
			#include "IrradianceFunctions.cginc"
			#include "RenderingFunctions.cginc"

			static const float3 kSphereCenter = float3(0.0, 1.0, 0.0);
			static const float kSphereRadius = 1.0;
			static const float3 kSphereAlbedo = float3(0.8, 0.8, 0.8);
			static const float3 kGroundAlbedo = float3(0.0, 0.0, 0.04);

			float exposure;
			float3 white_point;
			float3 earth_center;
			float2 sun_size;

			float4x4 frustumCorners;

			sampler2D transmittance_texture;
			sampler2D irradiance_texture;
			sampler3D scattering_texture;
			sampler3D single_mie_scattering_texture;


#ifdef RADIANCE_API_ENABLED
			IrradianceSpectrum GetSunAndSkyIrradiance(Position p, Direction normal, Direction sun_direction, out IrradianceSpectrum sky_irradiance)
			{
				return GetSunAndSkyIrradiance(transmittance_texture, irradiance_texture, p, normal, sun_direction, sky_irradiance);
			}
			RadianceSpectrum GetSkyRadianceToPoint(Position camera, Position _point, Length shadow_length, Direction sun_direction, out DimensionlessSpectrum transmittance)
			{
				return GetSkyRadianceToPoint(transmittance_texture,
					scattering_texture, single_mie_scattering_texture,
					camera, _point, shadow_length, sun_direction, transmittance);
			}
#else
			Illuminance3 GetSunAndSkyIrradiance(Position p, Direction normal, Direction sun_direction, out IrradianceSpectrum sky_irradiance)
			{
				IrradianceSpectrum sun_irradiance = GetSunAndSkyIrradiance(transmittance_texture, irradiance_texture, p, normal, sun_direction, sky_irradiance);
				sky_irradiance *= SKY_SPECTRAL_RADIANCE_TO_LUMINANCE;
				return sun_irradiance * SUN_SPECTRAL_RADIANCE_TO_LUMINANCE;
			}
			Luminance3 GetSkyRadianceToPoint(Position camera, Position _point, Length shadow_length, Direction sun_direction, out DimensionlessSpectrum transmittance)
			{
				return GetSkyRadianceToPoint(transmittance_texture,
					scattering_texture, single_mie_scattering_texture,
					camera, _point, shadow_length, sun_direction, transmittance) *
					SKY_SPECTRAL_RADIANCE_TO_LUMINANCE;
			}

#endif

			//--------------------------------------------------------------------------------------------------------------

			half4 CalculateLight(unity_v2f_deferred i)
			{
				float3 wpos;
				float2 uv;
				float atten, fadeDist;
				UnityLight light;
				UNITY_INITIALIZE_OUTPUT(UnityLight, light);
				UnityDeferredCalculateLightParams(i, wpos, uv, light.dir, atten, fadeDist);

				light.color = _LightColor.rgb * atten;

				// unpack Gbuffer
				half4 gbuffer0 = tex2D(_CameraGBufferTexture0, uv);
				half4 gbuffer1 = tex2D(_CameraGBufferTexture1, uv);
				half4 gbuffer2 = tex2D(_CameraGBufferTexture2, uv);
				UnityStandardData data = UnityStandardDataFromGbuffer(gbuffer0, gbuffer1, gbuffer2);

				float3 eyeVec = normalize(wpos - _WorldSpaceCameraPos);
				half oneMinusReflectivity = 1 - SpecularStrength(data.specularColor.rgb);
				
				

				UnityIndirect ind;
				UNITY_INITIALIZE_OUTPUT(UnityIndirect, ind);


				#if defined (DIRECTIONAL)

				float3 sky_irradiance;
				float3 sun_irradiance = GetSunAndSkyIrradiance(wpos - earth_center, data.normalWorld, light.dir, sky_irradiance);
				

				//---------------------------------- Hack -------------------------------------------
				float3 radiance = data.diffuseColor * (1.0 / PI) * (sun_irradiance + sky_irradiance);

				if (distance(wpos, earth_center) < top_radius)
				{
					float shadow_length = 0;
					float3 transmittance;
					float3 in_scatter = GetSkyRadianceToPoint(_WorldSpaceCameraPos - earth_center, wpos - earth_center, shadow_length, light.dir, transmittance);

					radiance = radiance * transmittance + in_scatter;
				}

				radiance = pow(float3(1, 1, 1) - exp(-radiance / white_point * exposure), 1.0 / 2.2);
				return half4(radiance, 1);
				//---------------------------------- Hack -------------------------------------------


				//---------------------------- This should be right solution ------------------------
				//sky_irradiance = pow(float3(1, 1, 1) - exp(-sky_irradiance / white_point * exposure), 1.0 / 2.2);
				//sun_irradiance = pow(float3(1, 1, 1) - exp(-sun_irradiance / white_point * exposure), 1.0 / 2.2);

				//light.color = sun_irradiance * atten;

				//ind.diffuse = ShadeSHPerPixel(data.normalWorld, sky_irradiance, wpos);
				//ind.diffuse = sky_irradiance;
				//ind.diffuse = 0;
				//ind.specular = 0;
				//---------------------------- This should be right solution ------------------------

				#else

				ind.diffuse = 0;
				ind.specular = 0;

				#endif

				half4 res = UNITY_BRDF_PBS(data.diffuseColor, data.specularColor, oneMinusReflectivity, data.smoothness, data.normalWorld, -eyeVec, light, ind);

				return res;
			}

			#ifdef UNITY_HDR_ON
			half4
			#else
			fixed4
			#endif
			frag(unity_v2f_deferred i) : SV_Target
			{
				half4 c = CalculateLight(i);
				#ifdef UNITY_HDR_ON
				return c;
				#else
				return exp2(-c);
				#endif
			}

			ENDCG
			}


			// Pass 2: Final decode pass.
			// Used only with HDR off, to decode the logarithmic buffer into the main RT
			Pass {
				ZTest Always Cull Off ZWrite Off
				Stencil {
					ref[_StencilNonBackground]
					readmask[_StencilNonBackground]
				// Normally just comp would be sufficient, but there's a bug and only front face stencil state is set (case 583207)
				compback equal
				compfront equal
			}

		CGPROGRAM
		#pragma target 3.0
		#pragma vertex vert
		#pragma fragment frag
		#pragma exclude_renderers nomrt

		#include "UnityCG.cginc"

		sampler2D _LightBuffer;
		struct v2f {
			float4 vertex : SV_POSITION;
			float2 texcoord : TEXCOORD0;
		};

		v2f vert(float4 vertex : POSITION, float2 texcoord : TEXCOORD0)
		{
			v2f o;
			o.vertex = UnityObjectToClipPos(vertex);
			o.texcoord = texcoord.xy;
		#ifdef UNITY_SINGLE_PASS_STEREO
			o.texcoord = TransformStereoScreenSpaceTex(o.texcoord, 1.0f);
		#endif
			return o;
		}

		fixed4 frag(v2f i) : SV_Target
		{
			return -log2(tex2D(_LightBuffer, i.texcoord));
		}
		ENDCG
		}

		}
			Fallback Off
}
