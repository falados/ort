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

integer BROADCAST_CHANNEL;
float RESCAN_TIME = 60.0;
integer OCCUPIED=0;
integer TOTAL_CHAIRS=0;
integer MIN_CHAIRS=1;
float Z_OFFSET = 0.0;
float RADIUS = 4;
float ANGLE = TWO_PI;
float ELBOW_ROOM = 1.5;
string CHAIR_OBJECT;
key gDataserverRequest;
integer MAX_CHAIRS = 100;
integer gReadLine;
integer CHAIR_LENGTH = 0;
integer ADDING_CHAIR = FALSE;
list CHAIR_LIST = [];

list get_rez_pos(integer length) {
	float t = 0;
	float theta = ANGLE;
	if( CHAIR_LENGTH > 0 )
	{
		t = llFabs((float)(length-1)/(float)length);
		theta = ANGLE/CHAIR_LENGTH;
	}
	float arc_len = RADIUS * theta;
	if( arc_len < ELBOW_ROOM )
	{
		RADIUS = ELBOW_ROOM / theta;
	}
	vector mypos = llGetPos();
	rotation myrot = llGetRot();
	float tangle = t*ANGLE;
	vector o = <llCos(tangle), llSin(tangle), 0> * RADIUS;
	o.z = Z_OFFSET;
	return [mypos+o*myrot, llEuler2Rot(<0,0,tangle+PI>)*myrot];
}

addChair() {
	if( !ADDING_CHAIR )
	{
		list p = get_rez_pos(MIN_CHAIRS);
		ADDING_CHAIR = TRUE;
		llRezObject(CHAIR_OBJECT,llList2Vector(p,0),ZERO_VECTOR,llList2Rot(p,1),BROADCAST_CHANNEL);
	}
}

check() {
	CHAIR_LENGTH = llGetListLength(CHAIR_LIST)/2;
	if( CHAIR_LENGTH < MAX_CHAIRS )
	{
		if( CHAIR_LENGTH < MIN_CHAIRS || OCCUPIED == CHAIR_LENGTH )
		{
			addChair();
		}
	}
	if( (CHAIR_LENGTH-OCCUPIED) > 1 && CHAIR_LENGTH > MIN_CHAIRS )
	{
		integer i = llListFindList(CHAIR_LIST,[0]);
		if( i != -1 )
		{
			kill( (i-1)/2 );
		}
	}
}

killAll()
{
	llRegionSay(BROADCAST_CHANNEL,"#DIE#");
}

forceGet()
{
	llRegionSay(BROADCAST_CHANNEL,"#FGET#");
}

kill(integer num )
{
	list params = [num,CHAIR_LENGTH,RADIUS,ANGLE,ELBOW_ROOM,Z_OFFSET];
	llRegionSay(BROADCAST_CHANNEL,"#RDIE#" + llList2CSV(params) );
	CHAIR_LIST = llListReplaceList(CHAIR_LIST, [], num*2, num*2+1);
}

killID(key id )
{
	llRegionSay(BROADCAST_CHANNEL,"#RDIE-" + (string)id );
}

scanChairs()
{
	integer len = llGetListLength(CHAIR_LIST)/2;
	integer i = 0;
	for( i = 0; i < len; ++i )
	{
		key id = llList2Key(CHAIR_LIST,i*2);
		if( llKey2Name(id) == "" ) {
			kill(i);
		}
	}
}

notifyRez(integer num, key id)
{
	list params = [num,CHAIR_LENGTH,RADIUS,ANGLE,ELBOW_ROOM,Z_OFFSET,id];
	llRegionSay(BROADCAST_CHANNEL,"#RREZ#" + llList2CSV(params) );
}

sendUpdate(integer num, key id )
{
	list params = [num,CHAIR_LENGTH,RADIUS,ANGLE,ELBOW_ROOM,Z_OFFSET, id];
	llRegionSay(BROADCAST_CHANNEL,"#RGET#" + llList2CSV(params) );
}

receiveChairResponse(integer channel, string name, key id, string message)
{
	if( message == "#SGET#" )
	{
		integer i = llListFindList(CHAIR_LIST, [id]);
		if( i == -1 )
		{
			killID(id);
		}
		sendUpdate(i/2,id);
	}
	if( llSubStringIndex(message, "#SREG#") == 0 )
	{
		integer i = llListFindList(CHAIR_LIST, [id]);
		if( i == -1 )
		{
			CHAIR_LIST += [id,0];
			++CHAIR_LENGTH;
			i = CHAIR_LENGTH;
			ADDING_CHAIR = FALSE;
		}
		llRegionSay(BROADCAST_CHANNEL,"#RREG" + (string)id);
	}
	if(llSubStringIndex(message, "#SSIT#") == 0 )
	{
		integer sitters = (integer)llGetSubString(message,6,-1);
		integer i = llListFindList(CHAIR_LIST, [id]);
		integer current = llList2Integer(CHAIR_LIST,i+1);
		if( i > -1 )
		{
			CHAIR_LIST = llListReplaceList(CHAIR_LIST,[ (sitters > 0 ) ],i+1,i+1);
			OCCUPIED = llFloor(llListStatistics(LIST_STAT_SUM,llList2ListStrided(llDeleteSubList(CHAIR_LIST,0,0), 0, -1, 2)));
			check();
		}
	}
}

default
{
    on_rez(integer param)
    {
        llResetScript();
    }
    state_entry()
    {
        if( llGetInventoryType("Config") == INVENTORY_NOTECARD)
        {
            gReadLine = 1;
            gDataserverRequest = llGetNotecardLine("Config",gReadLine);
        } else {
            llOwnerSay("Couldn't Find Notecard: 'Config'");
        }
    }
    dataserver(key req, string data)
    {
        if(req == gDataserverRequest)
        {
            if(data == EOF) state active;
            if(gReadLine == 1) 
            {
                CHAIR_OBJECT = data;
                if(llGetInventoryType(data) == INVENTORY_NONE) return;
            }
            if(gReadLine == 3) RADIUS = (float)data;
            if(gReadLine == 5) ELBOW_ROOM = (float)data;
            if(gReadLine == 7) 
            {
                MIN_CHAIRS = (integer)data;
                if(MIN_CHAIRS < 1) MIN_CHAIRS = 1;
            }
            if(gReadLine == 9) Z_OFFSET = (float)data;
            if(gReadLine == 11) 
            {
                MAX_CHAIRS = (integer)data;
                if(MAX_CHAIRS > 255 ) MAX_CHAIRS = 255; //Over 255 will overflow the mask
                else if(MAX_CHAIRS < 1) MAX_CHAIRS = 1; //What the hell are you doing?
            }
            gReadLine += 2;
            gDataserverRequest = llGetNotecardLine("Config",gReadLine);
        }
    }
    changed(integer change)
    {
        if( llGetInventoryType("Config") == INVENTORY_NOTECARD)
        {
            gReadLine = 1;
            gDataserverRequest = llGetNotecardLine("Config",gReadLine);
        } else {
            llOwnerSay("Couldn't Find Notecard: 'Config'");
        }
    }
}


state active
{
    state_entry()
    {
    	llSetTimerEvent(RESCAN_TIME);
        BROADCAST_CHANNEL = (integer)(llFrand(-1e6) - 1e6);
        llListen(BROADCAST_CHANNEL,"","","");
        check();
    }
    
    on_rez(integer param)
    {
    	killAll();
        llResetScript();
    }
    
    timer() {
    	ADDING_CHAIR = FALSE;
    	scanChairs();
    	check();
    }

    listen(integer channel, string name, key id, string message)
    {
    	receiveChairResponse(channel,name,id,message);
    	check();
    }
    
    changed(integer change)
    {
        if(change && CHANGED_INVENTORY)
        {
            killAll();
            llResetScript();
        }
    }
}