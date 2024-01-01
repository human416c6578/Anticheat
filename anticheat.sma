#include <amxmodx>
#include <fakemeta>
#include <fun>
#include <engine>
#include <hamsandwich>
#include <xs>
#include "get_user_fps"

#define RIGHT 1
#define LEFT -1

#define MAX_STRAFES 20

#define MAX_WARNINGS 30

#define FL_ONGROUND2	(FL_ONGROUND|FL_PARTIALGROUND|FL_INWATER|FL_CONVEYOR|FL_FLOAT)

const XO_CBASEPLAYERWEAPON = 4;
const m_pPlayer = 41;

enum detect_data
{
	detect_strafes,
	detect_move,
	detect_speed,
	detect_sync,
	Float:detect_maxSync,
	detect_maxStrafes,
	Float:detect_maxMove,
	Float:detect_maxSpeed
}

enum KEYS
{
	KEY_A, KEY_D, KEY_W, KEY_S
}

enum DATA
{
	BUTTON, KEY
}

new g_szKeyName[KEYS][] = 
{
	"[A]", "[D]", "[W]", "[S]"
};

new g_eInfo[][DATA] = 
{
	{IN_MOVELEFT, KEY_A}, {IN_MOVERIGHT, KEY_D}, {IN_FORWARD, KEY_W}, {IN_BACK, KEY_S}
};

static szLogFile[64];
static szLogEntriesFile[64];

new g_iStrafes[33];
new Float:g_fOldAngles[33];
new g_iStrafing[33];
new g_iGoodSync[33];
new bool:g_bJumped[33];
new g_iSyncFrames[33];
new bool:g_bOldOnGround[33];
new Float:g_fOldSpeed[33];

new g_iKeyFrames[33][KEYS];
new g_iOldKeyFrames[33][KEYS][10];

new g_iOldFps[MAX_PLAYERS][10];


new Float:g_fOldAngles2[33][3];
new Float:g_fOldUCVAngles[33][3];

new g_DetectEntries[33][detect_data];

new g_bIgnore[33];

public plugin_init(){

	register_forward(FM_CmdStart, "FM_CmdStart_Pre", 0);
	//register_forward(FM_PlayerPreThink, "FM_PlayerPreThink_Pre", 0);
	register_forward(FM_PlayerPostThink, "FM_PlayerPostThink_Pre", 0);

	new szWeaponName[32];
	for(new iId = CSW_P228; iId <= CSW_P90; iId++)
	{
		if(get_weaponname(iId, szWeaponName, charsmax(szWeaponName) ))
		{
			RegisterHam(Ham_Item_Deploy, szWeaponName, "Ham_Item_Deploy_Pre", 0);
		}
	}

	set_task(1.0, "check_fps", 6456, _, _, "b");
}

public plugin_cfg()
{
	static datestr[11], FilePath[64];
	get_localinfo("amxx_logs", FilePath, 63);
	get_time("%Y.%m.%d", datestr, 10);
	formatex(szLogFile, 63, "%s/anticheat/anticheat_%s.log", FilePath, datestr);
	formatex(szLogEntriesFile, 63, "%s/anticheat/anticheat_entries_%s.log", FilePath, datestr);
	if (!file_exists(szLogFile))
	{
		write_file(szLogFile, "Anticheat LogFile");
		write_file(szLogEntriesFile, "Anticheat Entries LogFile");
	}
}

public client_putinserver(id){
	new temp[detect_data];
	g_DetectEntries[id] = temp;
	for(new i;i<10;i++){
		g_iOldFps[id][i] = 0;
	}
}

public client_disconnected(id){
	if(g_DetectEntries[id][detect_move] || g_DetectEntries[id][detect_speed])
    {
        UTIL_LogDetection(id);
    }
		
}

public check_fps(taskid){
	new players[MAX_PLAYERS], iNum;
	get_players(players, iNum, "aceh", "CT");
	for(new i;i<iNum;i++){
		query_client_cvar(players[i], "fps_max", "cvar_result_func");
	}
}

public cvar_result_func(id, const cvar[], const value[], const param[])
{
	new iFpsMax = floatround(str_to_float(value));

	new iFpsReal = get_user_fps(id);

	new iFpsAverage = 0;

	static idxFps[MAX_PLAYERS];
	static g_iOldFpsMax[MAX_PLAYERS];

	if(iFpsMax != g_iOldFpsMax[id]){
		g_iOldFpsMax[id] = iFpsMax;
		for(new i;i<10;i++){
			g_iOldFps[id][i] = 0;
		}
	}
	
	if ( idxFps[id] < 9 )
		idxFps[id]++;
	else
		idxFps[id] = 0;

	g_iOldFps[id][idxFps[id]] = iFpsReal;

	for(new i;i<10;i++){
		iFpsAverage += g_iOldFps[id][i];
	}
	iFpsAverage /= 10;

	//client_print(id, print_chat, "Fps_max : %d | Fps Average %d", iFpsMax, iFpsAverage);

	if(iFpsAverage > iFpsMax + 50)
	{
		UTIL_LogUser(id, "Kicked for cheating Fps Max Exceeded, fps_max %d, real fps %d", iFpsMax, iFpsAverage);
		server_cmd("kick #%d Stop Cheating!", get_user_userid(id));
	}

	return PLUGIN_CONTINUE;
}

public FM_CmdStart_Pre(id, uc_handle, seed)
{
	if(!is_user_alive(id) || is_user_bot(id) || g_bIgnore[id]) return FMRES_IGNORED;		
	
	new iFlags = pev(id, pev_flags);
	new Float:fVelocity[3]; pev(id, pev_velocity, fVelocity);
	
	if(iFlags & FL_FROZEN || vector_length(fVelocity) < 100.0) return FMRES_IGNORED;
	
	new bool:bBlockSpeed, iButtons = get_uc(uc_handle, UC_Buttons);
	new Float:fForwardMove; get_uc(uc_handle, UC_ForwardMove, fForwardMove);
	new Float:fSideMove; get_uc(uc_handle, UC_SideMove, fSideMove);
	new Float:fViewAngles[3]; get_uc(uc_handle, UC_ViewAngles, fViewAngles);
	new Float:fValue = floatsqroot(fForwardMove * fForwardMove + fSideMove * fSideMove);
	new Float:fMaxSpeed = get_user_maxspeed(id);
	
	static Float:fAngles[3]; pev(id, pev_angles, fAngles);
	static Float:fAnglesDiff[3];xs_vec_sub(fAngles, g_fOldAngles2[id], fAnglesDiff);
	static Float:fUCVAnglesDiff[3]; xs_vec_sub(fViewAngles, g_fOldUCVAngles[id], fUCVAnglesDiff);
	new bool:isDiffAngle = xs_vec_equal(fAnglesDiff, Float:{0.0, 0.0, 0.0});
	if(!(isDiffAngle && fValue) && ~iFlags & FL_ONGROUND2)
	{
		if((fForwardMove > 0.0 && ~iButtons & IN_FORWARD || fForwardMove < 0.0 && ~iButtons & IN_BACK) && fUCVAnglesDiff[0] != 0.0)
		{
			bBlockSpeed = true;
			//UTIL_LogUser(id, "CheatMoves: forward move without button[%.1f]", fForwardMove);
			g_DetectEntries[id][detect_move]++;
			if(fForwardMove > g_DetectEntries[id][detect_maxMove])
				g_DetectEntries[id][detect_maxMove] = fForwardMove;
		}
		if(fSideMove > 0.0 && ~iButtons & IN_MOVERIGHT || fSideMove < 0.0 && ~iButtons & IN_MOVELEFT)
		{
			bBlockSpeed = true;
			//UTIL_LogUser(id, "CheatMoves: side move without button[%.1f]", fSideMove);
			g_DetectEntries[id][detect_move]++;
			if(fSideMove > g_DetectEntries[id][detect_maxMove])
				g_DetectEntries[id][detect_maxMove] = fSideMove;
		}
	}
	if(fValue > fMaxSpeed)
	{
		bBlockSpeed = true;
		//UTIL_LogUser(id, "CheatMoves: value[%.1f], fw[%.1f], sd[%.1f], maxspeed[%.1f]", fValue, fForwardMove, fSideMove, fMaxSpeed);
		g_DetectEntries[id][detect_speed]++;
		if(fValue > g_DetectEntries[id][detect_maxSpeed])
			g_DetectEntries[id][detect_maxSpeed] = fValue;
	}

	if(bBlockSpeed)
	{
		new Float:fVelocity[3]; pev(id, pev_velocity, fVelocity);
		xs_vec_mul_scalar(fVelocity, 0.2, fVelocity);
		set_pev(id, pev_velocity, fVelocity);
		if(g_DetectEntries[id][detect_speed] > MAX_WARNINGS || g_DetectEntries[id][detect_move] > MAX_WARNINGS){
			UTIL_LogUser(id, "Kicked for cheating MaxSpeed Exceeded / Max Moves Exceeded");
			server_cmd("kick #%d Stop Cheating!", get_user_userid(id));
		}
			
	}
	
	g_fOldAngles2[id] = fAngles;
	g_fOldUCVAngles[id] = fViewAngles;
	
	return FMRES_IGNORED;
}

/*public FM_PlayerPreThink_Pre(id)
{
	if(!is_user_alive(id) || g_bIgnore[id]) return FMRES_IGNORED;
	
	static idxKey[MAX_PLAYERS];
	static iButtons; iButtons = pev(id, pev_button);
	static iOldButton; iOldButton = pev(id, pev_oldbuttons);
	static bool:bOnGround; bOnGround = bool:(pev(id, pev_flags) & FL_ONGROUND);

	for(new i; i < sizeof(g_eInfo); i++)
	{
		new CheckButton = g_eInfo[i][BUTTON];
		new CheckKey = g_eInfo[i][KEY];
		
		// if current pressed button == button we're checking
		// we increase the key presses for that checked key
		if(iButtons & CheckButton)
		{
			g_iKeyFrames[id][CheckKey]++;
		}
		// if checked button is not the current button and last pressed button is checked button
		if(~iButtons & CheckButton && iOldButton & CheckButton) // switched strafe
		{
			// checking if the pressed for this time stayed the same for the last 5 strafes
			if(Check_Value(g_iKeyFrames[id][CheckKey], g_iOldKeyFrames[id][CheckKey]))
			{
				server_cmd("kick #%d Stop Cheating!", get_user_userid(id));
				UTIL_LogUser(id, "Kicked for cheating Perfect Strafes");

				//UTIL_LogUser(id, "CheatKeys: keyframe agreement[%d], key %s", g_iKeyFrames[id][CheckKey], g_szKeyName[CheckKey]);
			}
			//client_print(id, print_chat, "key frame%s OLD : %d | NEW : %d", g_szKeyName[CheckKey], g_iOldKeyFrames[id][CheckKey], g_iKeyFrames[id][CheckKey]);
			 
			if ( idxKey[id] < 9 )
				idxKey[id]++;
			else
				idxKey[id] = 0;

			g_iOldKeyFrames[id][CheckKey][idxKey[id]] = g_iKeyFrames[id][CheckKey];
			g_iKeyFrames[id][CheckKey] = 0;
		}
	}
	
	//Started jump
	if(bOnGround && iButtons & IN_JUMP && !g_bJumped[id])
	{
		g_bJumped[id] = true;
		g_iStrafing[id] = 0;
		g_iGoodSync[id] = 0;
		g_iSyncFrames[id] = 0;
	}
	//Finished jump
	else if(bOnGround && g_bJumped[id] && !g_bOldOnGround[id])
	{
		g_bJumped[id] = false;
		new Float:sync = float(g_iGoodSync[id])/float(g_iSyncFrames[id]) * 100;
		if(sync > 90.0 && g_iStrafes[id] >= 5)
		{
			//UTIL_LogUser(id, "Sync Frames %d/%d %f%", g_iGoodSync[id], g_iSyncFrames[id], sync);
			g_DetectEntries[id][detect_sync]++;
			if(sync > g_DetectEntries[id][detect_maxSync])
				g_DetectEntries[id][detect_maxSync] = sync;
		}
		
		if(g_iStrafes[id] >= MAX_STRAFES)
		{
			//UTIL_LogUser(id, "CheatStrafes: %d strafes", g_iStrafes[id]);
			g_DetectEntries[id][detect_strafes]++;
			if(g_iStrafes[id] >  g_DetectEntries[id][detect_maxStrafes])
				g_DetectEntries[id][detect_maxStrafes] = g_iStrafes[id];

		}

		g_iStrafes[id] = 0;

	}

	return FMRES_IGNORED;
}
*/
public FM_PlayerPostThink_Pre(id)
{
	if(!is_user_alive(id) || is_user_bot(id) || g_bIgnore[id]) return FMRES_IGNORED;
	
	static bool:bOnGround; bOnGround = bool:(pev(id, pev_flags) & FL_ONGROUND);
	
	static Float:fAngles[3]; pev(id, pev_angles, fAngles);
	static bTurning;
	
	bTurning = 0;
	
	if(fAngles[1] < g_fOldAngles[id])
	{
		bTurning = RIGHT;
	}
	else if(fAngles[1] > g_fOldAngles[id])
	{
		bTurning = LEFT;
	}
	g_fOldAngles[id] = fAngles[1];
	
	if(bOnGround) return FMRES_IGNORED;
	
	static iButtons; iButtons = pev(id, pev_button);
	static Float:fVelocity[3]; pev(id, pev_velocity, fVelocity);
	static Float:fSpeed; fSpeed = floatsqroot(fVelocity[0] * fVelocity[0] + fVelocity[1] * fVelocity[1]);
	
	if(bTurning != 0)
	{
		if(g_iStrafing[id] != LEFT && ((iButtons & IN_FORWARD) || (iButtons & IN_MOVELEFT)) && !(iButtons & IN_MOVERIGHT) && !(iButtons & IN_BACK))
		{
			g_iStrafing[id] = LEFT
			
			g_iStrafes[id]++;
		}
		else if(g_iStrafing[id] != RIGHT && ((iButtons & IN_BACK) || (iButtons & IN_MOVERIGHT)) && !(iButtons & IN_MOVELEFT) && !(iButtons & IN_FORWARD))
		{
			g_iStrafing[id] = RIGHT;
			
			g_iStrafes[id]++;
		}
	}
	
	if(g_fOldSpeed[id] < fSpeed)
	{
		g_iGoodSync[id]++;
	}
	
	g_iSyncFrames[id]++;
	
	g_fOldSpeed[id] = fSpeed;
	
	return FMRES_IGNORED;
}

public Ham_Item_Deploy_Pre(weapon)
{
	new player = get_pdata_cbase(weapon, m_pPlayer, XO_CBASEPLAYERWEAPON);
	g_bIgnore[player] = true;
	remove_task(player); set_task(0.5, "Task_RemoveIgnore", player);
}

public Task_RemoveIgnore(id)
{
	g_bIgnore[id] = false;
}

public Check_Value(num, array[])
{
	for(new i;i<5;i++)
	{
		if(num != array[i])
			return false;
	}
	return true;
}

public UTIL_LogUser(const id, const szCvar[], any:...)
{
	new iFile;
	if( (iFile = fopen(szLogFile, "a")) )
	{
		new szName[32], szAuthid[32], szIp[32], szTime[22];
		
		new message[128]; vformat(message, charsmax(message), szCvar, 3);

		get_user_name(id, szName, charsmax(szName));
		get_user_authid(id, szAuthid, charsmax(szAuthid));
		get_user_ip(id, szIp, charsmax(szIp), 1);
		get_time("%m/%d/%Y - %H:%M:%S", szTime, charsmax(szTime));
	
		//server_print("%s - %s", szName, message);

		fprintf(iFile, "L %s: <%s><%s><%s> %s^n", szTime, szName, szAuthid, szIp, message);
		fclose(iFile);
	}
}

public UTIL_LogDetection(const id)
{
	new iFile;
	if( (iFile = fopen(szLogEntriesFile, "a")) )
	{
		new szName[32], szAuthid[32], szIp[32], szTime[22];
		
		get_user_name(id, szName, charsmax(szName));
		get_user_authid(id, szAuthid, charsmax(szAuthid));
		get_user_ip(id, szIp, charsmax(szIp), 1);
		get_time("%m/%d/%Y - %H:%M:%S", szTime, charsmax(szTime));
		
		fprintf(iFile, "L %s: <%s><%s><%s> DETECTED ^nIllegal Strafes: %d, Max Strafes : %d ^n Illegal Moves: %d, Max Move Value %f ^n Illegal Speed: %d, Max Speed Value %f^n Illegal Sync: %d, Max Sync: %f ^n", szTime, szName, szAuthid, szIp, 
		 g_DetectEntries[id][detect_strafes],g_DetectEntries[id][detect_maxStrafes],
		  g_DetectEntries[id][detect_move],g_DetectEntries[id][detect_maxMove], 
		   g_DetectEntries[id][detect_speed],g_DetectEntries[id][detect_maxSpeed],
		   g_DetectEntries[id][detect_sync], g_DetectEntries[id][detect_maxSync]);
		fclose(iFile);
	}
}