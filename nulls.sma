#include <amxmodx>
#include <fakemeta>
#include "get_user_fps"

// anticheat against this alias, that doesn't allow the player to overlap a and d
// also checking the how many frames it takes to switch strafes
// because using this alias the frames it takes to switch strafes it's very consistent and low
/*
bind w +mfwd
bind s +mback
bind a +mleft
bind d +mright

alias +mfwd "-back;+forward;alias checkfwd +forward"
alias +mback "-forward;+back;alias checkback +back"
alias +mleft "-moveright;+moveleft;alias checkleft +moveleft"
alias +mright "-moveleft;+moveright;alias checkright +moveright"

alias -mfwd "-forward;checkback;alias checkfwd none"
alias -mback "-back;checkfwd;alias checkback none"
alias -mleft "-moveleft;checkright;alias checkleft none"
alias -mright "-moveright;checkleft;alias checkright none"

alias checkfwd none
alias checkback none
alias checkleft none
alias checkright none
alias none ""
*/

enum eData{
	Float:fSwitchTime,
	iStrafes,
	iOverlaps,
	iFps,
	iTimePlayed
}

new strafe_data[33][eData];

static szLogFile[64];

public plugin_init()
{
	register_forward(FM_PlayerPreThink, "FM_PlayerPreThink_Pre", 0);

	set_task(1.0, "check_fps", 3293, _, _, "b");
}

public plugin_cfg()
{
	static datestr[11], FilePath[64];
	get_localinfo("amxx_logs", FilePath, 63);
	get_time("%Y.%m.%d", datestr, 10);
	formatex(szLogFile, 63, "%s/alias/alias_%s.log", FilePath, datestr);
	if (!file_exists(szLogFile))
	{
		write_file(szLogFile, "Alias anticheat LogFile");
	}
}

// we can achieve this either by checking if the player ever overlaps the a/d
// like in the function below
// or by checking the time it takes to strafe ( switch from a to d or from d to a)

public FM_PlayerPreThink_Pre(id)
{
	if (!is_user_alive(id)) return FMRES_IGNORED;

	static Float:lastTime[33];
	static iButtons, iOldButtons;
	iButtons = pev(id, pev_button);
	iOldButtons = pev(id, pev_oldbuttons);

	if(iButtons & IN_MOVERIGHT && iButtons & IN_MOVELEFT ) // a and d overlap, not possible with alias
	{
		//server_print("Pressing both a/d");
		strafe_data[id][iOverlaps] += 1;
	}

	if((iOldButtons & IN_MOVERIGHT && iButtons & IN_MOVELEFT) || (iOldButtons & IN_MOVELEFT && iButtons & IN_MOVERIGHT) ) // strafing, changing from a direction to the other
	{
		//server_print("%f - %f", get_gametime(), get_gametime() - lastTime[id]);
		strafe_data[id][fSwitchTime] += get_gametime() - lastTime[id];
		strafe_data[id][iStrafes] += 1;
	}
	else if(iOldButtons & IN_MOVERIGHT || iOldButtons & IN_MOVELEFT){ // get lasttime the player pressed a or d
		lastTime[id] = get_gametime();
	}

	return FMRES_IGNORED;
}

public client_putinserver(id)
{
	strafe_data[id][fSwitchTime] = 0.0;
	strafe_data[id][iStrafes] = 0;
	strafe_data[id][iOverlaps] = 0;
	strafe_data[id][iFps] = 0;
	strafe_data[id][iTimePlayed] = 0;
}

public client_disconnected(id)
{
	if(strafe_data[id][iTimePlayed] < 60) return PLUGIN_CONTINUE;
	if(strafe_data[id][iStrafes] < 60) return PLUGIN_CONTINUE;

	new fpsAverage = strafe_data[id][iFps] / strafe_data[id][iTimePlayed];
	new Float:fAvgTime = strafe_data[id][fSwitchTime]/strafe_data[id][iStrafes];
	if(fAvgTime < (1.0 / (fpsAverage - (fpsAverage/5))))
	{
		UTIL_LogUser(id, "^n{^nAvgTime: %f^nStrafes: %d^nOverlaps: %d^nAvgFps: %d^nTimePlayed: %d^n}^n", fAvgTime, strafe_data[id][iStrafes], strafe_data[id][iOverlaps], fpsAverage, strafe_data[id][iTimePlayed]);
	}
	else if(strafe_data[id][iOverlaps] < (strafe_data[id][iStrafes] / 4) || strafe_data[id][iOverlaps] < 50)
	{
		UTIL_LogUser(id, "^n{^nAvgTime: %f^nStrafes: %d^nOverlaps: %d^nAvgFps: %d^nTimePlayed: %d^n}^n", fAvgTime, strafe_data[id][iStrafes], strafe_data[id][iOverlaps], fpsAverage, strafe_data[id][iTimePlayed]);
	}

	return PLUGIN_CONTINUE;
}

public check_fps(taskid){
	new players[MAX_PLAYERS], iNum;
	get_players(players, iNum, "aceh", "CT");
	for(new i;i<iNum;i++){
		strafe_data[players[i]][iFps] += get_user_fps(players[i]);
		strafe_data[players[i]][iTimePlayed] += 1;
	}
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

		fprintf(iFile, "L %s: <%s><%s><%s> %s^n", szTime, szName, szAuthid, szIp, message);
		fclose(iFile);
	}
}