#if defined _vphysics_included
  #endinput
#endif
#define _vphysics_included

native bool Phys_IsPhysicsObject(int iEntity);

native bool Phys_IsStatic(int iEntity);
native bool Phys_IsAsleep(int iEntity);
native bool Phys_IsHinged(int iEntity);
native bool Phys_IsCollisionEnabled(int iEntity);
native bool Phys_IsGravityEnabled(int iEntity);
native bool Phys_IsDragEnabled(int iEntity);
native bool Phys_IsMotionEnabled(int iEntity);
native void Phys_EnableCollisions(int iEntity, bool enable);
native void Phys_EnableGravity(int iEntity, bool enable);
native void Phys_EnableDrag(int iEntity, bool enable);
native void Phys_EnableMotion(int iEntity, bool enable);
native void Phys_Wake(int iEntity);
native void Phys_Sleep(int iEntity);
native void Phys_SetMass(int iEntity, float mass);
native float Phys_GetMass(int iEntity);
native void Phys_SetMaterialIndex(int iEntity, int materialIndex);
native int Phys_GetMaterialIndex(int iEntity);
native void Phys_BecomeHinged(int iEntity, int axis);
native void Phys_RemoveHinged(int iEntity);
native void Phys_LocalToWorld(int iEntity, float[3] worldPosition, const float[3] localPosition);
native void Phys_WorldToLocal(int iEntity, float[3] localPosition, const float[3] worldPosition);

native void Phys_CalculateForceOffset(int iEntity, const float[3] forceVector, const float[3] worldPosition, float[3] centerForce, float[3] centerTorque);
native void Phys_CalculateVelocityOffset(int iEntity, const float[3] forceVector, const float[3] worldPosition, float[3] centerVelocity, float[3] centerAngularVelocity);
native void Phys_ApplyForceCenter(int iEntity, const float[3] forceVector);
native void Phys_ApplyTorqueCenter(int iEntity, const float[3] torque);
native void Phys_AddVelocity(int iEntity, const float[3] velocity, const float[3] angularVelocity);
native void Phys_SetVelocity(int iEntity, const float[3] velocity, const float[3] angularVelocity, bool instantaneous = false);

native void Phys_GetEnvironmentGravity(float[3] gravity);
native void Phys_SetEnvironmentGravity(const float[3] gravity);
native float Phys_GetEnvironmentAirDensity();
native void Phys_SetEnvironmentAirDensity(float density);

native Handle Phys_CreateConstraintGroup(int additionalIterations = 0, int minErrorTicks = 15, float errorTolerance = 3.0);

native Handle Phys_CreateSpring(int startObject, int endObject, const float[3] startPos, const float[3] endPos, bool useLocalPositions, float naturalLength, float constant, float damping, float relativeDamping, bool onlyStretch);

native Handle Phys_CreateFixedConstraint(int referenceObject, int attachedObject, Handle constraintGroup, float strength = 1.0, float forceLimit = 0.0, float torqueLimit = 0.0, float bodyMassScaleRef = 1.0, float bodyMassScaleAttached = 1.0, bool isActive = true);
native Handle Phys_CreateLengthConstraint(int referenceObject, int attachedObject, Handle constraintGroup, const float[3] refPosition, const float[3] attachedPosition, float totalLength, float minLength = 0.0, float strength = 1.0, float forceLimit = 0.0, float torqueLimit = 0.0, float bodyMassScaleRef = 1.0, float bodyMassScaleAttached = 1.0, bool isActive = true);
native Handle Phys_CreateHingeConstraint(int referenceObject, int attachedObject, Handle constraintGroup, const float[3] worldPosition, const float[3] worldAxisDirection, float minRotation = 0.0, float maxRotation = 0.0, float angularVelocity = 0.0, float torque = 0.0, float strength = 1.0, float forceLimit = 0.0, float torqueLimit = 0.0, float bodyMassScaleRef = 1.0, float bodyMassScaleAttached = 1.0, bool isActive = true);

native Handle Phys_CreateFrictionSnapshot(int iEntity);
native bool Phys_IsFrictionSnapshotValid(Handle snapshot);
native bool Phys_NextFrictionData(Handle snapshot);
native int Phys_GetTouchingEntity(Handle snapshot);
native void Phys_GetContactPoint(Handle snapshot, float[3] contactPoint);

native int Phys_GetIndexOfMaterial(const char[] material);

forward void Phys_OnObjectWake(int iEntity);
forward void Phys_OnObjectSleep(int iEntity);

stock void Phys_ApplyForceOffset(int iEntity, const float[3] forceVector, const float[3] worldPosition)
{
	float centerForce[3];
	float centerTorque[3];

	Phys_CalculateForceOffset(iEntity, forceVector, worldPosition, centerForce, centerTorque);

	Phys_ApplyForceCenter(iEntity, centerForce);
	Phys_ApplyTorqueCenter(iEntity, centerTorque);
}

stock void Phys_AddVelocityOffset(int iEntity, const float[3] forceVector, const float[3] worldPosition)
{
	float centerVelocity[3];
	float centerAngularVelocity[3];

	Phys_CalculateVelocityOffset(iEntity, forceVector, worldPosition, centerVelocity, centerAngularVelocity);

	Phys_AddVelocity(iEntity, centerVelocity, centerAngularVelocity);
}

stock bool Phys_IsTouchingEntity(int iEntity, int other)
{
	Handle snapshot = Phys_CreateFrictionSnapshot(iEntity);

	bool touching = false;

	while (Phys_IsFrictionSnapshotValid(snapshot))
	{
		if (Phys_GetTouchingEntity(snapshot) == other)
		{
			touching = true;
			break;
		}

		Phys_NextFrictionData(snapshot);
	}

	delete snapshot;

	return touching;
}

/**
 * Do not edit below this line!
 */
public Extension __ext_vphysics = 
{
	name = "VPhysics",
	file = "vphysics.ext",
	autoload = 1,
	#if defined REQUIRE_EXTENSIONS
		required = 1,
	#else
		required = 0,
	#endif
}

#if !defined REQUIRE_EXTENSIONS
public void __ext_vphysics_SetNTVOptional()
{
	MarkNativeAsOptional("Phys_IsPhysicsObject");
	MarkNativeAsOptional("Phys_IsStatic");
	MarkNativeAsOptional("Phys_IsAsleep");
	MarkNativeAsOptional("Phys_IsHinged");
	MarkNativeAsOptional("Phys_IsCollisionEnabled");
	MarkNativeAsOptional("Phys_IsGravityEnabled");
	MarkNativeAsOptional("Phys_IsDragEnabled");
	MarkNativeAsOptional("Phys_IsMotionEnabled");
	MarkNativeAsOptional("Phys_EnableCollisions");
	MarkNativeAsOptional("Phys_EnableGravity");
	MarkNativeAsOptional("Phys_EnableDrag");
	MarkNativeAsOptional("Phys_EnableMotion");
	MarkNativeAsOptional("Phys_Wake");
	MarkNativeAsOptional("Phys_Sleep");
	MarkNativeAsOptional("Phys_SetMass");
	MarkNativeAsOptional("Phys_GetMass");
	MarkNativeAsOptional("Phys_SetMaterialIndex");
	MarkNativeAsOptional("Phys_GetMaterialIndex");
	MarkNativeAsOptional("Phys_BecomeHinged");
	MarkNativeAsOptional("Phys_RemoveHinged");
	MarkNativeAsOptional("Phys_LocalToWorld");
	MarkNativeAsOptional("Phys_WorldToLocal");
	MarkNativeAsOptional("Phys_CalculateForceOffset");
	MarkNativeAsOptional("Phys_CalculateVelocityOffset");
	MarkNativeAsOptional("Phys_ApplyForceCenter");
	MarkNativeAsOptional("Phys_ApplyTorqueCenter");
	MarkNativeAsOptional("Phys_AddVelocity");
	MarkNativeAsOptional("Phys_SetVelocity");
	MarkNativeAsOptional("Phys_GetEnvironmentGravity");
	MarkNativeAsOptional("Phys_SetEnvironmentGravity");
	MarkNativeAsOptional("Phys_GetEnvironmentAirDensity");
	MarkNativeAsOptional("Phys_SetEnvironmentAirDensity");
	MarkNativeAsOptional("Phys_CreateConstraintGroup");
	MarkNativeAsOptional("Phys_CreateSpring");
	MarkNativeAsOptional("Phys_CreateFixedConstraint");
	MarkNativeAsOptional("Phys_CreateLengthConstraint");
	MarkNativeAsOptional("Phys_CreateHingeConstraint");
	MarkNativeAsOptional("Phys_CreateFrictionSnapshot");
	MarkNativeAsOptional("Phys_IsFrictionSnapshotValid");
	MarkNativeAsOptional("Phys_NextFrictionData");
	MarkNativeAsOptional("Phys_GetTouchingEntity");
	MarkNativeAsOptional("Phys_GetContactPoint");
	MarkNativeAsOptional("Phys_GetIndexOfMaterial");
}
#endif
