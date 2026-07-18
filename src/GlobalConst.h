// SoftEther VPN Source Code - Developer Edition Master Branch
// Global Constants Header

#pragma warning(disable : 4819)

#ifndef	GLOBAL_CONST_H
#define	GLOBAL_CONST_H

//// Brand
// (Define it if building SoftEther VPN Project.)
#define	GC_SOFTETHER_VPN
#define	GC_SOFTETHER_OSS

//// Basic Variables

#define	CEDAR_PRODUCT_STR			"ComfyConnect"
#define	CEDAR_PRODUCT_STR_W			L"ComfyConnect"
#define	CEDAR_SERVER_STR			"ComfyConnect VPN Server"
#define	CEDAR_BRIDGE_STR			"ComfyConnect VPN Bridge"
#define	CEDAR_BETA_SERVER			"ComfyConnect VPN Server (Beta)"
#define	CEDAR_MANAGER_STR			"ComfyConnect VPN Server Manager"
#define	CEDAR_CUI_STR				"ComfyConnect VPN Command-Line Admin Tool"
#define CEDAR_ELOG					"ComfyConnect EtherLogger"
#define	CEDAR_CLIENT_STR			"ComfyConnect VPN Client"
#define CEDAR_CLIENT_MANAGER_STR	"ComfyConnect VPN Client Connection Manager"
#define	CEDAR_ROUTER_STR			"ComfyConnect VPN User-mode Router"
#define	CEDAR_SERVER_LINK_STR		"ComfyConnect VPN Server (Cascade Mode)"
#define	CEDAR_BRIDGE_LINK_STR		"ComfyConnect VPN Bridge (Cascade Mode)"
#define	CEDAR_SERVER_FARM_STR		"ComfyConnect VPN Server (Cluster RPC Mode)"



//// Default Port Number

#define	GC_DEFAULT_PORT		5555
#define	GC_CLIENT_CONFIG_PORT	9931
#define	GC_CLIENT_NOTIFY_PORT	9984


//// Software Name

#define	GC_SVC_NAME_VPNSERVER		"SEVPNSERVERDEV"
#define	GC_SVC_NAME_VPNCLIENT		"SEVPNCLIENTDEV"
#define	GC_SVC_NAME_VPNBRIDGE		"SEVPNBRIDGEDEV"



//// Registry

#define	GC_REG_COMPANY_NAME			"ComfyConnect"




//// Setup Wizard

#define	GC_SW_UIHELPER_REGVALUE		"ComfyConnect VPN Client UI Helper"
#define	GC_SW_SOFTETHER_PREFIX		"sedev"
#define	GC_SW_SOFTETHER_PREFIX_W	L"sedev"



//// VPN UI Components

#define	GC_UI_APPID_CM				L"ComfyConnect.ComfyConnect VPN Client"

#endif	// GLOBAL_CONST_H
