#include "tf_move_component.h"
#include "core/io/marshalls.h"
#include "core/math/math_defs.h"
#include "core/variant/variant_utility.h"

const inline Vector3 apply_friction(bool grounded, float GROUND_DECCEL, float DECCEL_RAMP_UP_SPEED, float delta, Vector3 vel) {
	if (!grounded) {
        return vel;
    }
    float speed = vel.length();
    float deccel = GROUND_DECCEL * delta;
    speed = VariantUtilityFunctions::move_toward(speed,0.,deccel*VariantUtilityFunctions::maxf(speed*.01,DECCEL_RAMP_UP_SPEED));
    return vel.normalized() * speed;
}

TfMoveComponent::TfMoveComponent() {
    JUMP_FORCE = 5.50545;
    GROUND_DECCEL = 400.;
    DECCEL_RAMP_UP_SPEED = .01905;
    TERMINAL_VELOCITY = 66.675;
    GRAVITY = 15.24;
    GROUND_SPEED = 4.572;
    GROUND_ACCEL = 45.72;
    AIR_SPEED = 1.42875;
    AIR_ACCEL = 20.;
    MAX_SLIDES = 5;
    MAX_SLOPE_ANGLE = .795;
    SURF_FRAC = .02;
    MIN_SURF_ANGLE = .01;
    CAN_HOLD_FOR_JUMP = false;
    can_hold_for_jump = 0.;
    grounded = false;
    just_jumped = false;
    just_landed = false;
    rocket_jumping = false;
}

// TfMoveComponent::~TfMoveComponent() {
//     player = nullptr;
// }

void TfMoveComponent::move(float delta) {
    ERR_FAIL_COND(player == nullptr);
    ERR_FAIL_COND(!VariantUtilityFunctions::is_instance_valid(player));
    // if (player == nullptr) {
    //     return;
    // }
    // if (!VariantUtilityFunctions::is_instance_valid(player)) {
    //     return;
    // }
    Vector3 vel = player->get_velocity();
	just_jumped = false;
    if (just_landed) {
        vel = apply_friction(grounded,GROUND_DECCEL,DECCEL_RAMP_UP_SPEED,delta,vel);
    }

    // Jumping.
    if (grounded && tryna_jump) {
        grounded = false;
        just_jumped = true;
        vel.y += JUMP_FORCE;
    }

    vel = apply_friction(grounded,GROUND_DECCEL,DECCEL_RAMP_UP_SPEED,delta,vel);

    Vector2 planar_velocity = Vector2(vel.x,vel.z);
    Vector3 remainder;
    Vector3 normal;
    // This assumes that the player's up_direction won't change during this function
    Vector3 up_direction = player->up_direction;
    // Vector3 adjusted_normal;

    float speed = planar_velocity.dot(input_dir);
    float target_speed;
    float accel;
    float add_speed;
    float slope_angle;

    if (grounded) {
        target_speed = GROUND_SPEED;
        accel = GROUND_ACCEL;
    }
    else {
        target_speed = AIR_SPEED;
        accel = AIR_ACCEL;
        vel.y = VariantUtilityFunctions::move_toward(vel.y,-TERMINAL_VELOCITY,GRAVITY*delta);
    }

    add_speed = VariantUtilityFunctions::clampf(target_speed - speed, 0., accel * delta);
    planar_velocity += input_dir * add_speed;
    vel.x = planar_velocity.x;
    vel.z = planar_velocity.y;

    // Handle collisions
    just_landed = false;
    
    Ref<KinematicCollision3D> collision;
    for (int i = 0; i < MAX_SLIDES; i++) {
        collision = player->_move((!normal.is_zero_approx())? remainder.slide(normal) : vel * delta,false);
        
        // Didn't collide and moved fully through the world in a single step.
        if (collision.is_null()) {
            break;
        }

        remainder = collision->get_remainder();
        normal = collision->get_normal();

        // Apparently this is how surfing happens
        if (!grounded) {
            // This is only here because it was there in the gdscript stuff
            // adjusted_normal = normal;
            vel = vel.slide(normal); // vel = vel.slide(adjusted_normal);
            slope_angle = normal.angle_to(up_direction);
            if (slope_angle < VariantUtilityFunctions::maxf(MAX_SLOPE_ANGLE-vel.length() * SURF_FRAC,MIN_SURF_ANGLE)) {
                grounded = true;
                just_landed = true;
                vel.y = 0.;
            }
        }
        else {
            vel = vel.slide(normal);
        }
    }

    if (grounded) {
        
        rocket_jumping = false;
        
        collision = player->_move(Vector3::DOWN * .25, true, 0.);
        if (collision.is_valid()) {
            if (vel.y <= 0.) {
                player->_move(Vector3::DOWN);
            }
        }

        collision = player->_move(Vector3::DOWN*.1, true, 0.);
        if (collision.is_valid()){
            slope_angle = collision->get_normal().angle_to(up_direction);
            grounded = slope_angle < MAX_SLOPE_ANGLE;
        }
        else {
            grounded = false;
        }
    }

    player->set_velocity(vel);
}

CharacterBody3D* TfMoveComponent::get_player() {
	return player;
}
void TfMoveComponent::set_player(CharacterBody3D* p_player) {
	player = p_player;
}
float TfMoveComponent::get_JUMP_FORCE() {
	return JUMP_FORCE;
}
void TfMoveComponent::set_JUMP_FORCE(float p_JUMP_FORCE) {
	JUMP_FORCE = p_JUMP_FORCE;
}
float TfMoveComponent::get_GROUND_DECCEL() {
	return GROUND_DECCEL;
}
void TfMoveComponent::set_GROUND_DECCEL(float p_GROUND_DECCEL) {
	GROUND_DECCEL = p_GROUND_DECCEL;
}
float TfMoveComponent::get_DECCEL_RAMP_UP_SPEED() {
	return DECCEL_RAMP_UP_SPEED;
}
void TfMoveComponent::set_DECCEL_RAMP_UP_SPEED(float p_DECCEL_RAMP_UP_SPEED) {
	DECCEL_RAMP_UP_SPEED = p_DECCEL_RAMP_UP_SPEED;
}
float TfMoveComponent::get_TERMINAL_VELOCITY() {
	return TERMINAL_VELOCITY;
}
void TfMoveComponent::set_TERMINAL_VELOCITY(float p_TERMINAL_VELOCITY) {
	TERMINAL_VELOCITY = p_TERMINAL_VELOCITY;
}
float TfMoveComponent::get_GRAVITY() {
	return GRAVITY;
}
void TfMoveComponent::set_GRAVITY(float p_GRAVITY) {
	GRAVITY = p_GRAVITY;
}
float TfMoveComponent::get_GROUND_SPEED() {
	return GROUND_SPEED;
}
void TfMoveComponent::set_GROUND_SPEED(float p_GROUND_SPEED) {
	GROUND_SPEED = p_GROUND_SPEED;
}
float TfMoveComponent::get_GROUND_ACCEL() {
	return GROUND_ACCEL;
}
void TfMoveComponent::set_GROUND_ACCEL(float p_GROUND_ACCEL) {
	GROUND_ACCEL = p_GROUND_ACCEL;
}
float TfMoveComponent::get_AIR_SPEED() {
	return AIR_SPEED;
}
void TfMoveComponent::set_AIR_SPEED(float p_AIR_SPEED) {
	AIR_SPEED = p_AIR_SPEED;
}
float TfMoveComponent::get_AIR_ACCEL() {
	return AIR_ACCEL;
}
void TfMoveComponent::set_AIR_ACCEL(float p_AIR_ACCEL) {
	AIR_ACCEL = p_AIR_ACCEL;
}
int TfMoveComponent::get_MAX_SLIDES() {
	return MAX_SLIDES;
}
void TfMoveComponent::set_MAX_SLIDES(int p_MAX_SLIDES) {
	MAX_SLIDES = p_MAX_SLIDES;
}
float TfMoveComponent::get_MAX_SLOPE_ANGLE() {
	return MAX_SLOPE_ANGLE;
}
void TfMoveComponent::set_MAX_SLOPE_ANGLE(float p_MAX_SLOPE_ANGLE) {
	MAX_SLOPE_ANGLE = p_MAX_SLOPE_ANGLE;
}
float TfMoveComponent::get_SURF_FRAC() {
	return SURF_FRAC;
}
void TfMoveComponent::set_SURF_FRAC(float p_SURF_FRAC) {
	SURF_FRAC = p_SURF_FRAC;
}
float TfMoveComponent::get_MIN_SURF_ANGLE() {
	return MIN_SURF_ANGLE;
}
void TfMoveComponent::set_MIN_SURF_ANGLE(float p_MIN_SURF_ANGLE) {
	MIN_SURF_ANGLE = p_MIN_SURF_ANGLE;
}
bool TfMoveComponent::get_CAN_HOLD_FOR_JUMP() {
	return CAN_HOLD_FOR_JUMP;
}
void TfMoveComponent::set_CAN_HOLD_FOR_JUMP(bool p_CAN_HOLD_FOR_JUMP) {
	CAN_HOLD_FOR_JUMP = p_CAN_HOLD_FOR_JUMP;
}
float TfMoveComponent::get_can_hold_for_jump() {
	return can_hold_for_jump;
}
void TfMoveComponent::set_can_hold_for_jump(float p_can_hold_for_jump) {
	can_hold_for_jump = p_can_hold_for_jump;
}
bool TfMoveComponent::get_grounded() {
	return grounded;
}
void TfMoveComponent::set_grounded(bool p_grounded) {
	grounded = p_grounded;
}
bool TfMoveComponent::get_just_jumped() {
	return just_jumped;
}
void TfMoveComponent::set_just_jumped(bool p_just_jumped) {
	just_jumped = p_just_jumped;
}
bool TfMoveComponent::get_just_landed() {
	return just_landed;
}
void TfMoveComponent::set_just_landed(bool p_just_landed) {
	just_landed = p_just_landed;
}
bool TfMoveComponent::get_rocket_jumping() {
	return rocket_jumping;
}
void TfMoveComponent::set_rocket_jumping(bool p_rocket_jumping) {
	rocket_jumping = p_rocket_jumping;
}
bool TfMoveComponent::get_tryna_jump() {
	return tryna_jump;
}
void TfMoveComponent::set_tryna_jump(bool p_tryna_jump) {
	tryna_jump = p_tryna_jump;
}
Vector2 TfMoveComponent::get_input_dir() {
	return input_dir;
}
void TfMoveComponent::set_input_dir(Vector2 p_input_dir) {
	input_dir = p_input_dir;
}
Vector2 TfMoveComponent::get_aim_angle() {
	return aim_angle;
}
void TfMoveComponent::set_aim_angle(Vector2 p_aim_angle) {
	aim_angle = p_aim_angle;
}

void TfMoveComponent::_notification(int p_what){
    switch (p_what) {
        case NOTIFICATION_PARENTED: {
            Node* parent = get_parent();
            if (parent == nullptr) {
                return;
            }
            CharacterBody3D* bruh = Object::cast_to<CharacterBody3D>(parent);
            if (bruh != nullptr) {
                player = bruh;
            }
            return;
        }
        case NOTIFICATION_UNPARENTED: {
            player = nullptr;
            return;
        }
    }
}

void TfMoveComponent::_bind_methods(){
ClassDB::bind_method(D_METHOD("move", "delta"), &TfMoveComponent::move);
// ClassDB::bind_method(D_METHOD("set_player", "value"), &TfMoveComponent::set_player);
// ClassDB::bind_method(D_METHOD("get_player"), &TfMoveComponent::get_player);
// ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "player", PROPERTY_HINT_NODE_TYPE, "", 6U, "CharacterBody3D"), "set_player", "get_player"); // unfinished and u should prolly change this
ClassDB::bind_method(D_METHOD("set_JUMP_FORCE", "value"), &TfMoveComponent::set_JUMP_FORCE);
ClassDB::bind_method(D_METHOD("get_JUMP_FORCE"), &TfMoveComponent::get_JUMP_FORCE);
ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "JUMP_FORCE"), "set_JUMP_FORCE", "get_JUMP_FORCE"); // unfinished and u should prolly change this
ClassDB::bind_method(D_METHOD("set_GROUND_DECCEL", "value"), &TfMoveComponent::set_GROUND_DECCEL);
ClassDB::bind_method(D_METHOD("get_GROUND_DECCEL"), &TfMoveComponent::get_GROUND_DECCEL);
ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "GROUND_DECCEL"), "set_GROUND_DECCEL", "get_GROUND_DECCEL"); // unfinished and u should prolly change this
ClassDB::bind_method(D_METHOD("set_DECCEL_RAMP_UP_SPEED", "value"), &TfMoveComponent::set_DECCEL_RAMP_UP_SPEED);
ClassDB::bind_method(D_METHOD("get_DECCEL_RAMP_UP_SPEED"), &TfMoveComponent::get_DECCEL_RAMP_UP_SPEED);
ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "DECCEL_RAMP_UP_SPEED"), "set_DECCEL_RAMP_UP_SPEED", "get_DECCEL_RAMP_UP_SPEED"); // unfinished and u should prolly change this
ClassDB::bind_method(D_METHOD("set_TERMINAL_VELOCITY", "value"), &TfMoveComponent::set_TERMINAL_VELOCITY);
ClassDB::bind_method(D_METHOD("get_TERMINAL_VELOCITY"), &TfMoveComponent::get_TERMINAL_VELOCITY);
ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "TERMINAL_VELOCITY"), "set_TERMINAL_VELOCITY", "get_TERMINAL_VELOCITY"); // unfinished and u should prolly change this
ClassDB::bind_method(D_METHOD("set_GRAVITY", "value"), &TfMoveComponent::set_GRAVITY);
ClassDB::bind_method(D_METHOD("get_GRAVITY"), &TfMoveComponent::get_GRAVITY);
ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "GRAVITY"), "set_GRAVITY", "get_GRAVITY"); // unfinished and u should prolly change this
ClassDB::bind_method(D_METHOD("set_GROUND_SPEED", "value"), &TfMoveComponent::set_GROUND_SPEED);
ClassDB::bind_method(D_METHOD("get_GROUND_SPEED"), &TfMoveComponent::get_GROUND_SPEED);
ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "GROUND_SPEED"), "set_GROUND_SPEED", "get_GROUND_SPEED"); // unfinished and u should prolly change this
ClassDB::bind_method(D_METHOD("set_GROUND_ACCEL", "value"), &TfMoveComponent::set_GROUND_ACCEL);
ClassDB::bind_method(D_METHOD("get_GROUND_ACCEL"), &TfMoveComponent::get_GROUND_ACCEL);
ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "GROUND_ACCEL"), "set_GROUND_ACCEL", "get_GROUND_ACCEL"); // unfinished and u should prolly change this
ClassDB::bind_method(D_METHOD("set_AIR_SPEED", "value"), &TfMoveComponent::set_AIR_SPEED);
ClassDB::bind_method(D_METHOD("get_AIR_SPEED"), &TfMoveComponent::get_AIR_SPEED);
ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "AIR_SPEED"), "set_AIR_SPEED", "get_AIR_SPEED"); // unfinished and u should prolly change this
ClassDB::bind_method(D_METHOD("set_AIR_ACCEL", "value"), &TfMoveComponent::set_AIR_ACCEL);
ClassDB::bind_method(D_METHOD("get_AIR_ACCEL"), &TfMoveComponent::get_AIR_ACCEL);
ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "AIR_ACCEL"), "set_AIR_ACCEL", "get_AIR_ACCEL"); // unfinished and u should prolly change this
ClassDB::bind_method(D_METHOD("set_MAX_SLIDES", "value"), &TfMoveComponent::set_MAX_SLIDES);
ClassDB::bind_method(D_METHOD("get_MAX_SLIDES"), &TfMoveComponent::get_MAX_SLIDES);
ADD_PROPERTY(PropertyInfo(Variant::INT, "MAX_SLIDES"), "set_MAX_SLIDES", "get_MAX_SLIDES"); // unfinished and u should prolly change this
ClassDB::bind_method(D_METHOD("set_MAX_SLOPE_ANGLE", "value"), &TfMoveComponent::set_MAX_SLOPE_ANGLE);
ClassDB::bind_method(D_METHOD("get_MAX_SLOPE_ANGLE"), &TfMoveComponent::get_MAX_SLOPE_ANGLE);
ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "MAX_SLOPE_ANGLE", PropertyHint(1), "0.0,90.0,0.001,radians", 4102), "set_MAX_SLOPE_ANGLE", "get_MAX_SLOPE_ANGLE"); // unfinished and u should prolly change this
ClassDB::bind_method(D_METHOD("set_SURF_FRAC", "value"), &TfMoveComponent::set_SURF_FRAC);
ClassDB::bind_method(D_METHOD("get_SURF_FRAC"), &TfMoveComponent::get_SURF_FRAC);
ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "SURF_FRAC"), "set_SURF_FRAC", "get_SURF_FRAC"); // unfinished and u should prolly change this
ClassDB::bind_method(D_METHOD("set_MIN_SURF_ANGLE", "value"), &TfMoveComponent::set_MIN_SURF_ANGLE);
ClassDB::bind_method(D_METHOD("get_MIN_SURF_ANGLE"), &TfMoveComponent::get_MIN_SURF_ANGLE);
ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "MIN_SURF_ANGLE"), "set_MIN_SURF_ANGLE", "get_MIN_SURF_ANGLE"); // unfinished and u should prolly change this
// ClassDB::bind_method(D_METHOD("set_CAN_HOLD_FOR_JUMP", "value"), &TfMoveComponent::set_CAN_HOLD_FOR_JUMP);
// ClassDB::bind_method(D_METHOD("get_CAN_HOLD_FOR_JUMP"), &TfMoveComponent::get_CAN_HOLD_FOR_JUMP);
// ADD_PROPERTY(PropertyInfo(Variant::BOOL, "CAN_HOLD_FOR_JUMP"), "set_CAN_HOLD_FOR_JUMP", "get_CAN_HOLD_FOR_JUMP"); // unfinished and u should prolly change this
ClassDB::bind_method(D_METHOD("set_can_hold_for_jump", "value"), &TfMoveComponent::set_can_hold_for_jump);
ClassDB::bind_method(D_METHOD("get_can_hold_for_jump"), &TfMoveComponent::get_can_hold_for_jump);
ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "can_hold_for_jump"), "set_can_hold_for_jump", "get_can_hold_for_jump"); // unfinished and u should prolly change this
ClassDB::bind_method(D_METHOD("set_grounded", "value"), &TfMoveComponent::set_grounded);
ClassDB::bind_method(D_METHOD("get_grounded"), &TfMoveComponent::get_grounded);
ADD_PROPERTY(PropertyInfo(Variant::BOOL, "grounded"), "set_grounded", "get_grounded"); // unfinished and u should prolly change this
ClassDB::bind_method(D_METHOD("set_just_jumped", "value"), &TfMoveComponent::set_just_jumped);
ClassDB::bind_method(D_METHOD("get_just_jumped"), &TfMoveComponent::get_just_jumped);
ADD_PROPERTY(PropertyInfo(Variant::BOOL, "just_jumped"), "set_just_jumped", "get_just_jumped"); // unfinished and u should prolly change this
ClassDB::bind_method(D_METHOD("set_just_landed", "value"), &TfMoveComponent::set_just_landed);
ClassDB::bind_method(D_METHOD("get_just_landed"), &TfMoveComponent::get_just_landed);
ADD_PROPERTY(PropertyInfo(Variant::BOOL, "just_landed"), "set_just_landed", "get_just_landed"); // unfinished and u should prolly change this
ClassDB::bind_method(D_METHOD("set_rocket_jumping", "value"), &TfMoveComponent::set_rocket_jumping);
ClassDB::bind_method(D_METHOD("get_rocket_jumping"), &TfMoveComponent::get_rocket_jumping);
ADD_PROPERTY(PropertyInfo(Variant::BOOL, "rocket_jumping"), "set_rocket_jumping", "get_rocket_jumping"); // unfinished and u should prolly change this
ClassDB::bind_method(D_METHOD("set_tryna_jump", "value"), &TfMoveComponent::set_tryna_jump);
ClassDB::bind_method(D_METHOD("get_tryna_jump"), &TfMoveComponent::get_tryna_jump);
ADD_PROPERTY(PropertyInfo(Variant::BOOL, "tryna_jump"), "set_tryna_jump", "get_tryna_jump"); // unfinished and u should prolly change this
ClassDB::bind_method(D_METHOD("set_input_dir", "value"), &TfMoveComponent::set_input_dir);
ClassDB::bind_method(D_METHOD("get_input_dir"), &TfMoveComponent::get_input_dir);
ADD_PROPERTY(PropertyInfo(Variant::VECTOR2, "input_dir"), "set_input_dir", "get_input_dir"); // unfinished and u should prolly change this
ClassDB::bind_method(D_METHOD("set_aim_angle", "value"), &TfMoveComponent::set_aim_angle);
ClassDB::bind_method(D_METHOD("get_aim_angle"), &TfMoveComponent::get_aim_angle);
ADD_PROPERTY(PropertyInfo(Variant::VECTOR2, "aim_angle"), "set_aim_angle", "get_aim_angle"); // unfinished and u should prolly change this
}