(() => {

let xml = `
<Button id="BasisConsole">
	<Button id="BasisConsoleHeader">
		<Panel id="BasisConsoleHeaderTabstrip"/>
		<Label id="BasisConsoleHeaderCross" text="X"/>
	</Button>
	<Panel id="BasisConsolePage_Terminal" class="BasisConsolePage">
		<Label id="BasisConsoleTerminalOutput" text="AzazaA"/>
	</Panel>
	<Panel id="BasisConsolePage_Code" class="BasisConsolePage"/>
</Button>
`

VOID_COLOR = '#212326'
BACKGROUND_COLOR = '#323539'
HEADER_COLOR = '#40444a'
TEXT_COLOR = '#8590a3'
GLOW_HEADER_COLOR = '#8993a4'
GLOW_TEXT_COLOR = '#dce1ea'

let css = `
#BasisConsole {
	width: 1000px;
	height: 700px;
	flow-children: down;
}

#BasisConsoleHeader{
	width: 100%;
	height: 30px;
	background-color: ${HEADER_COLOR};
}

#BasisConsoleHeader #BasisConsoleHeaderTabstrip{
	width: 100%;
	height: 100%;
	flow-children: right;
}

#BasisConsoleHeader .TabstripButton{
	height: 100%;
	background-color: ${HEADER_COLOR};
}
#BasisConsoleHeader .TabstripButton:hover{
	background-color: ${GLOW_HEADER_COLOR};
}
#BasisConsoleHeader .TabstripButton.Selected:update{
	background-color: ${BACKGROUND_COLOR};
}

#BasisConsoleHeader .TabstripButtonLabel{
	vertical-align: center;
	text-align: center;
	font-size: 18px;
	padding-top: 1px;
	margin-left: 8px;
	margin-right: 8px;
	color: ${TEXT_COLOR};
}
#BasisConsoleHeader .TabstripButton:hover .TabstripButtonLabel{
	color: ${GLOW_TEXT_COLOR};
}
#BasisConsoleHeader .TabstripButton.Selected:update .TabstripButtonLabel{
	color: ${GLOW_TEXT_COLOR};
}

#BasisConsoleHeaderCross {
	height: 100%;
	color: ${TEXT_COLOR};
	text-align: center;
	font-weight: bold;
	font-size: 24px;
	horizontal-align: right;
	padding-right: 4px;
	padding-left: 4px;
	transform: scaleX(1.2);
	transform-origin: 100% 0%;
	background-color: none;
}
#BasisConsoleHeaderCross:hover {
	color: ${GLOW_TEXT_COLOR};
	background-color: #c14e4e;
}

.BasisConsolePage{
	height: 100%;
	width: 100%;
	background-color: ${BACKGROUND_COLOR};
}
`

let {imprt, exprt} = GameUI.CustomUIConfig().basis
let basic = imprt('basis/basic')
let {Vector} = imprt('basis/geometry')

exprt('basis/console', {
	_reload() {
		if(this.panel && this.panel.IsValid()){
			this.panel.DeleteAsync(0)
		}

		this._init()
	},

	_init() {

		// create panel

		let parent = $.GetContextPanel().GetParent()
		this.panel = basic.createPanels(parent, xml)[0]
		this.restartPos()
		this.visible = false

		// util

		let child = id => this.panel.FindChildTraverse(id)

		// pages
		
		this.pager = new basic.Pager()
		this.pager.addPage('terminal', child('BasisConsolePage_Terminal'))
		this.pager.addPage('code', child('BasisConsolePage_Code'))

		// tabstrip

		let tabstrip = new basic.Tabstrip(this.panel.FindChildTraverse('BasisConsoleHeaderTabstrip'))
		tabstrip.addTab('terminal', 'TERMINAL')
		tabstrip.addTab('code', 'RUN CODE')
		this.pager.setTabstrip(tabstrip)

		// decorate

		basic.applyCSS(this.panel, css)

		// cross button

		this.panel.FindChildTraverse('BasisConsoleHeaderCross').SetPanelEvent('onactivate', () => {
			this.visible = false
		})

		// menu button

		basic.menuButton({
			id: 'BasisConsoleBtn',
			image: "s2r://panorama/images/hud/reborn/icon_combat_log_psd.vtex",
			imageSize: 26,
			click: () => this.visible = !this.visible,
			rclick: () => this.restartPos(),
		})

		// drag
		
		let cur
		let pos

		this.panel.FindChildTraverse('BasisConsoleHeader').SetDraggable(true)

		$.RegisterEventHandler('DragStart', this.panel, (_, setup) => {
			setup.displayPanel = this.panel
			cur = new Vector(GameUI.GetCursorPosition())
			pos = new Vector(this.panel.GetPositionWithinWindow())
			return true
		})

		$.RegisterEventHandler('DragEnd', this.panel, () => {
			let dcur = new Vector(GameUI.GetCursorPosition()).sub(cur)
			let npos = pos.add(dcur).screenSize(true)
			this.panel.SetPositionInPixels(npos.x, npos.y, npos.z)
		})
	},

	restartPos(){
		this.panel.SetPositionInPixels(50, 120, 0)
	},

	get visible(){
		return this.panel.visible
	},
	set visible(v){
		this.panel.visible = v
	},
})




})();