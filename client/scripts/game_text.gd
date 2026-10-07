extends RefCounted

const ERRORS = {
	"invalid_credentials":"Email or password is incorrect.", "account_exists":"This account already exists. Sign in to continue.",
	"invalid_email":"Enter a valid email address.", "invalid_name":"Choose a name of the required length, without control characters.",
	"password_length":"Use a password of 10–256 characters.", "unauthorized":"Your session expired. Sign in to continue.",
	"rate_limited":"Please wait a moment before trying again.", "queue_busy":"Work is already in progress. Wait for this queue to finish.",
	"insufficient_resources":"Your stores cannot cover this order yet.", "building_required":"Construct or upgrade the required building first.",
	"keep_required":"Upgrade the Keep before improving this building.", "warehouse_required":"Expand the Warehouse before upgrading the Keep.",
	"academy_required":"Upgrade the Academy to support this research.", "research_required":"Complete the prerequisite research first.",
	"maximum_level":"This improvement has reached its highest level.", "army_capacity":"Expand the Barracks to house more soldiers.",
	"army_preset_required":"Organize an army before issuing a march order.", "army_preset_empty":"Assign soldiers to this army first.",
	"army_preset_stale":"This army has suffered losses. Update its composition before marching.", "insufficient_units":"There are not enough available soldiers for this army.",
	"army_changed":"Your forces changed. Review the army and try again.", "target_not_connected":"Secure neighboring territory to reach this holding.",
	"target_protected":"This holding is protected. Choose another target.", "target_occupied":"This holding is occupied. Wait for its recovery.",
	"already_owned":"This territory already belongs to your realm.", "friendly_territory":"This territory belongs to an ally.",
	"clan_war_required":"Declare war before attacking a clan fort.", "clan_level_15_required":"Reach Level 15 before founding a clan.",
	"clan_permission":"Your clan role cannot issue this order.", "clan_cooldown":"Your settlement must rest before another relocation.",
	"clan_at_war":"Relocation is unavailable during a clan war.", "clan_region_full":"This clan region has no free settlement plots.",
	"already_in_clan":"You already belong to a clan.", "already_exists":"This name or tag is already in use.",
	"clan_not_found":"This clan is no longer available.", "player_not_found":"No ruler with that name was found.",
	"request_id_conflict":"This order conflicts with an earlier request. Refresh your realm.", "hospital_required":"Build a Hospital to treat the wounded.",
	"insufficient_wounded":"There are not enough wounded soldiers for this treatment.", "commander_locked":"Build a Commander Hall to appoint this commander.",
	"goal_incomplete":"Complete the objective before claiming its reward.", "goal_claimed":"This reward has already been claimed.",
	"war_active":"One of these clans is already at war.", "war_cooldown":"These clans must recover before declaring another war.",
	"war_preparation":"The war is still in preparation. Prepare your armies.", "chat_too_fast":"Wait a few seconds before sending another message.",
	"clan_required":"Join a clan to use this channel.", "message_unavailable":"This message is no longer available.",
	"player_name_ambiguous":"Several rulers share that name. Ask for their realm name.", "siege_required":"Assign siege engines before attacking a fortified holding.",
	"transfer_leadership_required":"Appoint another leader before leaving the clan.",
}
const NAMES = {
	"square_banner":"Square Banner", "swallowtail":"Swallowtail Banner", "pennant":"Pennant", "accepted":"Accepted", "pending":"Awaiting Approval", "rejected":"Declined", "withdrawn":"Withdrawn", "player_name_ambiguous":"Several rulers share that name. Ask for their realm name.",
	"balanced":"Balanced", "line":"Battle Line", "wedge":"Cavalry Wedge", "shield":"Shield Wall", "square":"Defensive Square", "skirmish":"Skirmish Line",
	"aggressive":"Aggressive", "defensive":"Defensive", "approval":"By Application", "open":"Open Admission", "preparation":"Preparation", "battle":"War in Progress",
	"result":"War Concluded", "cancelled":"War Cancelled", "none":"Borders Unchanged", "captured":"Territory Secured", "occupied":"Holding Occupied", "fort_captured":"Fort Secured",
	"neutral":"Unclaimed Territory", "resource":"Resource Holding", "npc":"Border Garrison", "fort":"Clan Fort", "settlement":"Settlement",
	"leader":"Leader", "officer":"Officer", "member":"Member", "arden":"Arden Vale", "serah":"Serah Rowan", "idris":"Idris Fen", "building":"Construction", "training":"Training", "research":"Research",
}
static func copy(value: String) -> String: return TranslationServer.translate(value)
static func error(code: String) -> String:
	return copy(str(ERRORS.get(code,"Your order could not be completed. Refresh your realm and try again.")))
static func name_for(value: String) -> String:
	return copy(str(NAMES.get(value,value.replace("_"," ").capitalize())))
static func duration(seconds: int) -> String:
	seconds = maxi(0,seconds)
	if seconds >= 86400: return "%dd %dh" % [seconds/86400,(seconds%86400)/3600]
	if seconds >= 3600: return "%dh %dm" % [seconds/3600,(seconds%3600)/60]
	return "%dm %02ds" % [seconds/60,seconds%60]

static func order(path: String) -> String:
	var messages = {"/v2/buildings/upgrade":"Construction has begun.", "/v2/research/start":"Research has begun.", "/v2/units/train":"Your soldiers are training.",
		"/v2/units/heal":"The wounded are receiving treatment.", "/v2/army/preset":"Your army orders are ready.", "/v2/army/preset/delete":"The army preset has been disbanded.",
		"/v2/empire/customize":"Your realm bears its new heraldry.", "/v2/commanders/recruit":"A commander has joined your court.", "/v2/goals/claim":"Your reward has been claimed.",
		"/v2/clans/join":"Your clan request has been received.", "/v2/clans/create":"Your clan has been founded.", "/v2/clans/donate":"Your contribution has reached the treasury.",
		"/v2/clans/describe":"The clan charter has been published.", "/v2/chat/send":"Your message has been sent.", "/v2/chat/block":"This ruler's messages are hidden.",
		"/v2/chat/report":"Your report has been received.", "/v2/inbox/read":"Dispatch marked as read.", "/v2/wars/declare":"War has been declared. Prepare your armies."}
	return copy(str(messages.get(path,"Your order has been issued.")))
