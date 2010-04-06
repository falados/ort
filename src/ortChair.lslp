//    This file is part of Open Round-Table.
//
//    Open Round-Table is free software: you can redistribute it and/or modify
//    it under the terms of the GNU General Public License as published by
//    the Free Software Foundation, either version 3 of the License, or
//    (at your option) any later version.
//
//    Open Round-Table is distributed in the hope that it will be useful,
//    but WITHOUT ANY WARRANTY; without even the implied warranty of
//    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//    GNU General Public License for more details.
//
//    You should have received a copy of the GNU General Public License
//    along with Open Round-Table.  If not, see <http://www.gnu.org/licenses/>.
//
//    Author: Falados Kapuskas
//    Version: 1.2

integer COMM_CHANNEL = -1;
float REFRESH_TIME = 1.0;
integer ACTIVITY_COUNT = 1;
integer GET_UPDATE_COUNT = 0;
integer GET_UPDATE_COUNT_RECUR = 100;
key SOURCE_TABLE = NULL_KEY;
integer SITTING_AVATARS = 0;
integer gListenHandle_Table;
integer gChairIndex = 0;
integer gChairMax = 0;

float RADIUS = 0.0;
float ANGLE = 0.0;
float ELBOW_ROOM = 0.0;
float Z_OFFSET = 0.0;

integer SIT_RESPONSE_NONE = 0;
integer SIT_RESPONSE_DIE = 10;

stateSetup() {
	gListenHandle_Table = llListen(COMM_CHANNEL,"","","");
}

registerChair() {
	llRegionSay(COMM_CHANNEL,"#SREG#");
}

registerSit(integer avatars)
{
	llRegionSay(COMM_CHANNEL,"#SSIT#" + (string)avatars);	
}
getUpdate()
{
	llRegionSay(COMM_CHANNEL,"#SGET#");
}
update( list params )
{
	gChairMax = llList2Integer(params,1); 
	RADIUS = llList2Float(params,2);
	ANGLE =  llList2Float(params,3);
	ELBOW_ROOM = llList2Float(params,4);
	Z_OFFSET = llList2Float(params,5);
}
apply() {
	if( llKey2Name(SOURCE_TABLE) == "" ) llDie();
	list params = llGetObjectDetails(SOURCE_TABLE,[OBJECT_POS,OBJECT_ROT]);
	if( params == [] ) llDie();
	rotation rot = llList2Rot(params,1);
	vector   pos = llList2Vector(params,0);
	float t = 0;
	float theta = ANGLE;
	if( gChairMax > 0 )
	{
		t = llFabs((float)gChairIndex/(float)gChairMax);
		theta = ANGLE/gChairMax;
	}
	float arc_len = RADIUS * theta;
	if( arc_len < ELBOW_ROOM )
	{
		RADIUS = ELBOW_ROOM / theta;
	}
	float tangle = t*ANGLE;
	vector o = <llCos(tangle), llSin(tangle), 0> * RADIUS;
	o.z = Z_OFFSET;
	vector position = pos + o*rot;
	llSetPrimitiveParams([PRIM_POSITION,position,PRIM_ROTATION,llEuler2Rot(<0,0,tangle+PI>)*rot]);
}

integer receiveRegisterResponse(integer channel, string name, key id, string message)
{
	if( llSubStringIndex(message, "#RREG" + (string)llGetKey()) == 0 )
	{
		SOURCE_TABLE = id;
		return TRUE;
	}
	return FALSE;
}

integer receiveTableResponse(integer channel, string name, key id, string message)
{
	if( id != SOURCE_TABLE )
	{
		return SIT_RESPONSE_NONE;
	}
	if( message == "#DIE#" || message == "#RDIE-" + (string)llGetKey() )
	{
		return SIT_RESPONSE_DIE;
	}
	list params = llCSV2List( llGetSubString(message, 6, -1) );
	integer chair_num = llList2Integer(params,0);
	integer chair_max = llList2Integer(params,1);
	if( llSubStringIndex(message, "#RDIE#") == 0 )
	{
		update(params);
		if( chair_num == gChairIndex ) { return SIT_RESPONSE_DIE; }
		if( chair_num < gChairIndex ) {
			--gChairIndex;
		}
		apply();
	}
	if( llSubStringIndex(message, "#RREZ#") == 0 )
	{
		update(params);
		key chair_key = llList2Key(params,6);
		if( chair_key == llGetKey() )
		{
			gChairIndex = chair_num;
		}
		if( chair_num < gChairIndex ) {
			++gChairIndex;
		}
		apply();
	}
	if( llSubStringIndex(message, "#RGET#") == 0 )
	{
		update(params);
		key chair_key = llList2Key(params,6);
		if( chair_key == llGetKey() )
		{
			gChairIndex = chair_num;
		}
		apply();
	}
	if( message == "#FGET#" )
	{
		getUpdate();
	}
	return SIT_RESPONSE_NONE;
}

default {
	on_rez(integer param) {
		if( param != 0 )
		{
			COMM_CHANNEL = param;
			state register;
		}
	}
}

state register {
	on_rez(integer p) { llResetScript(); }
	state_entry() 
	{
		stateSetup();
		registerChair();
	}
	listen( integer channel, string name, key id, string message )
	{
		if( receiveRegisterResponse(channel,name,id,message) )
		{
			state main;
		}
	}
}

state main {
	state_entry() {
		stateSetup();
		getUpdate();
		llSetTimerEvent(REFRESH_TIME);
	}
	timer() {
		if( ACTIVITY_COUNT > 1 ) --ACTIVITY_COUNT;
		float refresh = REFRESH_TIME / (float)ACTIVITY_COUNT;
		if( refresh < 0.05 ) refresh = 0.05;
		llSetTimerEvent(refresh);
		apply();
		if( GET_UPDATE_COUNT >= GET_UPDATE_COUNT_RECUR )
		{
			getUpdate();
			GET_UPDATE_COUNT = 0;
		} else {
			++GET_UPDATE_COUNT;
		}
	}
	changed(integer change)
	{
		if( change & CHANGED_LINK )
		{
			integer i;
			integer prims = llGetNumberOfPrims();
			SITTING_AVATARS = 0;
			for( i = 2; i <= prims; ++i )
			{
					if( llGetAgentSize(llGetLinkKey(i)) != ZERO_VECTOR )
					{
						++SITTING_AVATARS;
					}
			}
			registerSit(SITTING_AVATARS);
		}
	}
	listen( integer channel, string name, key id, string message )
	{
		integer response = receiveTableResponse(channel,name,id,message);
		if( response == SIT_RESPONSE_DIE  ) { llDie(); } else { ACTIVITY_COUNT += 2; }
	}
}
