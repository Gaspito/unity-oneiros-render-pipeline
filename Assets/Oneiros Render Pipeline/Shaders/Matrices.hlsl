#if !defined(MATRICES_INCLUDED)
#define MATRICES_INCLUDED

float4x4 TranslateMatrix(float4x4 m, float3 v)
{
    float x = v.x, y = v.y, z = v.z;
    m[0][3] = x;
    m[1][3] = y;
    m[2][3] = z;
    return m;
}

float4x4 ScaleMatrix(float4x4 m, float3 v)
{
    float x = v.x, y = v.y, z = v.z;

    m[0][0] *= x;
    m[1][0] *= y;
    m[2][0] *= z;
    m[0][1] *= x;
    m[1][1] *= y;
    m[2][1] *= z;
    m[0][2] *= x;
    m[1][2] *= y;
    m[2][2] *= z;
    m[0][3] *= x;
    m[1][3] *= y;
    m[2][3] *= z;

    return m;
}

float4x4 RotationMatrix(float4 quat)
{
    float4x4 m = float4x4(float4(0, 0, 0, 0), float4(0, 0, 0, 0), float4(0, 0, 0, 0), float4(0, 0, 0, 0));

    float x = quat.x, y = quat.y, z = quat.z, w = quat.w;
    float x2 = x + x, y2 = y + y, z2 = z + z;
    float xx = x * x2, xy = x * y2, xz = x * z2;
    float yy = y * y2, yz = y * z2, zz = z * z2;
    float wx = w * x2, wy = w * y2, wz = w * z2;

    m[0][0] = 1.0 - (yy + zz);
    m[0][1] = xy - wz;
    m[0][2] = xz + wy;

    m[1][0] = xy + wz;
    m[1][1] = 1.0 - (xx + zz);
    m[1][2] = yz - wx;

    m[2][0] = xz - wy;
    m[2][1] = yz + wx;
    m[2][2] = 1.0 - (xx + yy);

    m[3][3] = 1.0;

    return m;
}

float4 QuaternionFromEuler(float3 euler)
{
    float4 q;
    float cosX = cos(euler.x * 0.5);
    float sinX = sin(euler.x * 0.5);
    float cosY = cos(euler.y * 0.5);
    float sinY = sin(euler.y * 0.5);
    float cosZ = cos(euler.z * 0.5);
    float sinZ = sin(euler.z * 0.5);
    
    q.x = sinZ * cosY * cosX - cosZ * sinY * sinX;
    q.y = cosZ * sinY * cosX + sinZ * cosY * sinX;
    q.z = cosZ * cosY * sinX - sinZ * sinY * cosX;
    q.w = cosZ * cosY * cosX + sinZ * sinY * sinX;

    return q;
}

float4x4 AxisMatrix(float3 right, float3 up, float3 forward)
{
    float3 xaxis = right;
    float3 yaxis = up;
    float3 zaxis = forward;
    return float4x4(
		xaxis.x, yaxis.x, zaxis.x, 0,
		xaxis.y, yaxis.y, zaxis.y, 0,
		xaxis.z, yaxis.z, zaxis.z, 0,
		0, 0, 0, 1
	);
}

float4x4 LookAtMatrix(float3 forward, float3 up)
{
    float3 xaxis = normalize(cross(forward, up));
    float3 yaxis = normalize(up);
    float3 zaxis = normalize(cross(xaxis, up));
    return AxisMatrix(xaxis, yaxis, zaxis);
}

float4x4 LookAtMatrix(float3 forward)
{
    float3 up = float3(0, 1, 0);
    float3 xaxis = normalize(cross(forward, up));
    float3 yaxis = normalize(cross(xaxis, forward));
    float3 zaxis = normalize(forward);
    return AxisMatrix(xaxis, yaxis, zaxis);
}

float4 MatrixToQuaternion(float4x4 m)
{
    float tr = m[0][0] + m[1][1] + m[2][2];
    float4 q = float4(0, 0, 0, 0);

    if (tr > 0)
    {
        float s = sqrt(tr + 1.0) * 2; // S=4*qw 
        float divideS = 1.0 / s;
        q.w = 0.25 * s;
        q.x = (m[2][1] - m[1][2]) * divideS;
        q.y = (m[0][2] - m[2][0]) * divideS;
        q.z = (m[1][0] - m[0][1]) * divideS;
    }
    else if ((m[0][0] > m[1][1]) && (m[0][0] > m[2][2]))
    {
        float s = sqrt(1.0 + m[0][0] - m[1][1] - m[2][2]) * 2; // S=4*qx 
        float divideS = 1.0 / s;
        q.w = (m[2][1] - m[1][2]) * divideS;
        q.x = 0.25 * s;
        q.y = (m[0][1] + m[1][0]) * divideS;
        q.z = (m[0][2] + m[2][0]) * divideS;
    }
    else if (m[1][1] > m[2][2])
    {
        float s = sqrt(1.0 + m[1][1] - m[0][0] - m[2][2]) * 2; // S=4*qy
        float divideS = 1.0 / s;
        q.w = (m[0][2] - m[2][0]) * divideS;
        q.x = (m[0][1] + m[1][0]) * divideS;
        q.y = 0.25 * s;
        q.z = (m[1][2] + m[2][1]) * divideS;
    }
    else
    {
        float s = sqrt(1.0 + m[2][2] - m[0][0] - m[1][1]) * 2; // S=4*qz
        float divideS = 1.0 / s;
        q.w = (m[1][0] - m[0][1]) * divideS;
        q.x = (m[0][2] + m[2][0]) * divideS;
        q.y = (m[1][2] + m[2][1]) * divideS;
        q.z = 0.25 * s;
    }

    return q;
}

float4x4 TRSMatrix(float3 position, float4 rotation, float3 scale)
{
    float4x4 m = RotationMatrix(rotation);
    m = ScaleMatrix(m, scale);
    m = TranslateMatrix(m, position);
    return m;
}

float4x4 TDSMatrix(float3 position, float3 direction, float3 scale)
{
    float4x4 m = LookAtMatrix(direction);
    m = ScaleMatrix(m, scale);
    m = TranslateMatrix(m, position);
    return m;
}

#endif