"use strict";

(() => {
	let basis = GameUI.CustomUIConfig().basis
	let awaiting = []
	let ready_callbacks = []
	
	if(!basis){
		basis = {
			modules: {},
		}
		GameUI.CustomUIConfig().basis = basis
	}

	basis.imprt = (module, local) => {
		if(module in basis.modules){
			let mod = basis.modules[module]
			if(!mod.__imported){
				mod.__imported = true
				basic.ocall(mod.imprt)
			}
			return mod
		} else if(!local) {
			let mod = {}
			basis.modules[module] = mod
			awaiting.push(module)
			basic.afterState(DOTA_GameState.DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP, () => {
				GameEvents.SendCustomGameEventToServer('sv_basis_panorama_module', {
					module: module,
				})
			})
			return mod
		}
	}

	basis.exprt = (module, t) => {
		let mod = basis.modules[module]
		if(!mod){
			mod = {}
			basis.modules[module] = mod
		}
		for(let [k, v] of Object.entries(t)){
			mod[k] = v
		}
	}

	basis.ready = (f) => {
		if(awaiting.length == 0){
			f()
		} else {
			ready_callbacks.push(f)
		}
	}

	basis.moduleReady = module => {
		let i = awaiting.indexOf(module)
		if(i >= 0) awaiting.splice(i, 1)
		if(awaiting.length == 0){
			let onready = ready_callbacks
			ready_callbacks = []
			onready.forEach(f => f())
		}
	}

// ------------------------------------------
// basic
// ------------------------------------------

	let snippetAttributes = ({
		Label: [
			['allowtextselection', 'false'],
		],
	})

	let _state
	let onStateCallbacks = {}
	let __merge_ignore = undefined

	let basic = {
		fd: (...args) => {
			return args.find(v => v != undefined)
		},

		dget: (source, key, ...args) => {
			if(key == undefined){
				return source
			} else {
				return basic.dget(source[key], ...args.slice(1))
			}
		},

		dgos: (target, key, def, ...args) => {
			let val = target[key]
			let last = (args.length == 0)
			if(!val){
				val = last ? def : {}
				target[key] = val
			}
			return last ? val : basic.dgos(val, def, ...args.slice(1))
		},

		dlet: (...args) => {
			let [f] = args.splice(-1, 1)
			let v = basic.dget(...args)
			if(v != undefined){
				f(v)
			}
		},

		ocall: (f, ...args) => {
			if(f) f(...args)
		},

		bool: x => x == 'true' ? true : x == 'false' ? false : x,

		stringify: x => {
			return typeof(x) == 'string' ? `"${x}"` : x.toString()
		},

		backward: (a, callback) => {
			a.slice().reverse().forEach(callback)
		},

		merge: (left, right, ...others) => {
			let result
			let topcall = (__merge_ignore == undefined)
			if(topcall) {
				__merge_ignore = new Map()
			}

			if(right == undefined){
				result = left
			} else if(typeof(right) != 'object'){
				result = basic.merge(right, ...others)
			} else if(typeof(left) != 'object'){
				result = basic.merge({}, right, ...others)
			} else {
				__merge_ignore.set(left, left)
				__merge_ignore.set(right, left)
				for(let [k, v] of Object.entries(right)){
					let leftv = left[k]
					left[k] = __merge_ignore.get(leftv) || __merge_ignore.get(v) || basic.merge(leftv, v)
				}
				__merge_ignore.delete(left)
				__merge_ignore.delete(right)
				result = basic.merge(left, ...others)
			}

			if(topcall){
				__merge_ignore = undefined
			}

			return result
		},

		lprint: msg => {
			msg.split('\n').forEach(line => $.Msg(line))
		},

		loc: (key, def) => {
			let str = $.Localize(key)
			if(key == str){
				return def || ''
			}
			return str
		},

		getHud: () => {
			let hud = $.GetContextPanel()
			while(hud.GetParent()) hud = hud.GetParent()
			return hud 
		},

		onState: (state, callback) => {
			let callbacks = basic.dgos(onStateCallbacks, state, [])
			callbacks.push(callback)
		},

		afterState: (state, callback) => {
			if(Game.GameStateIsBefore(state)){
				basic.onState(state, callback)
			} else {
				callback()
			}
		},

		subscribe: (event, callback) => {
			return GameEvents.Subscribe(event, t => {
				if(t.event_key == basis.EVENT_KEY){
					callback(t.event_data)
				}
			})
		},

		matchSelector: (panel, selector) => {
			if(!panel || !panel.IsValid()) return false
			return selector.split(',').some(selector => {
				let allowParent = false
				return selector.match(/[#.\w]+/g).reverse().every(temp => {
					while(true){
						let ok = temp.match(/^[^#.]+|[#.][^#.]+/g).every(basic => {
							let name = basic.slice(1)
							switch(basic[0]){
								case '#': return panel.id == name
								case '.': return panel.BHasClass(name)
							}
							return panel.paneltype == basic
						})
						if(ok){
							allowParent = true
							return true
						}
						else {
							if(allowParent){
								panel = panel.GetParent()
								if(!panel) return false
							} else {
								return false
							}
						}
					}
				})
			})
		},

		applyCSS: (panel, css, recursive) => {
			if(!panel || !panel.IsValid()) return

			if(typeof css == 'string'){
				css = css.replace(/\/\/.*/g, '')
				let temps = css.match(/[^{}]+{[^{}]+?}/g)
				css = {}
				temps.forEach(temp => {
					let match = temp.match(/([^{}]+){([^{}]+?)}/)
					let selector = match[1].trim()
					let style = {}
					match[2].match(/[^:]+:[^;]+;/g).forEach(line => {
						let match = line.match(/([^:]+):([^;]+);/)
						style[match[1].trim()] = match[2].trim()
					})
					css[selector] = style
				})
			}
			
			for(let [selector, style] of Object.entries(css)){
				if(basic.matchSelector(panel, selector)){
					basic.applyStyle(panel, style)
				}
			}

			if(basic.fd(recursive, true)){
				panel.Children().forEach(child => basic.applyCSS(child, css))
			}
		},

		applyStyle: (panel, style) => {
			for(let [k, v] of Object.entries(style)){
				panel.style[k] = v
			}
		},

		parseXML: (xml, options) => {
			options = basic.merge({
				raw: false,
				trim: true,
			}, options)
			
			let root = []
			let stack = [root]
			const current = () => stack[stack.length - 1]

			const parseString = s => s.replace(/&lt;/g, '<')
				.replace(/&gt;/gi, '>')
				.replace(/&quot;/gi, '"')
				.replace(/&apos;/gi, "'")
				.replace(/&amp;/gi, '&')
				.replace(/&#(\d+);/gi, (_, n) => String.fromCodePoint(parseInt(n, 10)))
				.replace(/&#x(\d+);/gi, (_, n) => String.fromCodePoint(parseInt(n, 16)))
			
			const parseNode = () => {
				if(!xml) return

				let match = /^[^<]+/.exec(xml)
				if(match){
					if(options.raw){
						let text = match[0]
						if(options.trim) text = text.trim()
						if(text){
							current().push(parseString(text))
						}
					}
					return match
				}

				match = /^<([\w\d\-_]+)[^\/<>]*(\/?)>/.exec(xml)
				if(match){
					let text = match[0]
					let node = {
						name: match[1],
						attributes: {},
						children: [],
					}

					let re = /([\w\d\-_]+)\s*=\s*"([^"]*?)"/g, pair
					while(pair = re.exec(text)){
						node.attributes[pair[1]] = pair[2]
					}

					current().push(node)
					if(!match[2]){
						stack.push(node.children)
					}
					return match
				}

				match = /^<\/.*?>/.exec(xml)
				if(match){
					stack.pop()
					return match
				}
			}

			let match
			while(match = parseNode()){
				xml = xml.slice(match.index + match[0].length)
			}
			
			return root
		},

		panelEvents: {
			onactivate: true,
			oncancel: true,
			oncontextmenu: true,
			ondblclick: true,
			ondeselect: true,
			oneconsetloaded: true,
			onfilled: true,
			onfindmatchend: true,
			onfindmatchstart: true,
			onfocus: true,
			onblur: true,
			ondescendantfocus: true,
			ondescendantblur: true,
			oninputsubmit: true,
			onload: true,
			onmouseactivate: true,
			onmouseout: true,
			onmouseover: true,
			onmovedown: true,
			onmoveleft: true,
			onmoveright: true,
			onmoveup: true,
			onnotfilled: true,
			onpagesetupsuccess: true,
			onpopupsdismissed: true,
			onselect: true,
			ontabforward: true,
			ontabbackward: true,
			ontextentrychange: true,
			ontextentrysubmit: true,
			onscrolledtobottom: true,
			onscrolledtorightedge: true,
			ontooltiploaded: true,
			onvaluechanged: true,
		},

		createSnippet: (parent, type, id, attributes) => {
			let name = type
			let specific = snippetAttributes[type]
			if(specific) specific.forEach(kv => {
				let key = kv[0]
				let def = kv[1]
				if(key in attributes && attributes[key] != def){
					name += '__' + key
				}
			})
			let p = $.CreatePanel(type, basis.snippetLoader, id)
			p.BLoadLayoutSnippet(name)
			p.SetParent(parent)
			return p
		},

		createPanels: (parent, xml, callback) => {
			if(typeof xml == 'string') xml = basic.parseXML(xml)
			
			let created = []

			xml.forEach(node => {
				let id = node.attributes.id; delete node.attributes.id
				let panel = basic.createSnippet(parent, node.name, id || '', node.attributes)
				created.push(panel)

				for(let [key, val] of Object.entries(node.attributes)){
					if(key == 'class'){
						val.split(/\s+/).forEach(cls => panel.AddClass(cls))
					}
					else if(key == 'acceptsfocus'){
						panel.SetAcceptsFocus(basic.bool(val))
					}
					else if(basic.panelEvents[key]){
						if(callback){
							panel.SetPanelEvent(key, (...a) => callback(val, ...a))
						}
					}
					else if(panel[key] != undefined){
						let nval = +val
						if(!isNaN(nval)) val = nval
						else val = basic.bool(val)
						panel[key] = val
					}
					else {
						// SetAttribute useless?
					}
				}

				basic.createPanels(panel, node.children, callback)
			})

			return created
		},

		multiline: class {			
			constructor(parent, id){
				this.panel = $.CreatePanel('Panel', parent, id)
				this.panel.AddClass('BasisMultiline')
				this.panel.style.flowChildren = 'down'
				this.__text = ''
				this.__html = false
			}

			get text(){
				return this.__text
			}
			set text(v){
				this.__text = v.toString()
				this.update()
			}

			get html(){
				return this.__html
			}
			set html(v){
				this.__html = v ? true : false
				this.update()
			}

			update(){
				this.panel.RemoveAndDeleteChildren()
				let lines = this.text.split('\n')

				if(this.html){
					let tags = []
					lines = lines.map(line => {
						let newline = line
						basic.backward(tags, t => newline = t.tag + newline)
						basic.dlet(line.match(/<.+?>/g), s => s.forEach(tag => {
							if(tag[1] == '/'){
								tags.pop()
							} else {
								tags.push({
									tag: tag,
									tagname: tag.match(/\w+/),
								})
							}
						}))
						basic.backward(tags, t => newline += `</${t.tagname}>`)
						return newline
					})
				}

				lines.forEach(line => {
					let label = $.CreatePanel('Label', this.panel, '')
					label.AddClass('BasisMultiline_Line')
					label.html = this.html
					label.text = line
				})
			}
		},
	}

	function __dprint_parseformat(format){
		if(typeof(format) == 'string'){
			format = __dprint.format[format]
		}
		format = basic.merge({}, format)
		format.lastspace = basic.fd(format.lastspace, format.space)
		format.child = basic.fd(format.child, format.space)
		format.lastchild = basic.fd(format.lastchild, format.child)
		return basic.merge({}, __dprint.format.simple, format)
	}

	function __dprint(object, options, meta){
		options = options || {}
		let t = {
			print: basic.fd(options.print, basic.lprint),
			expand: options.expand || (o => typeof(o) == 'object'),
			keys: basic.fd(options.keys, true),
			format: __dprint_parseformat(options.format),
		}
		t.tostring = options.tostring || t.format.tostring
	
		meta = meta || {
			printed: new Map(),
		}
	
		let output = ''
		let prefix = meta.prefix || ''
		let closestring = t.format.mapright.length > 0
	
		output += t.tostring(object, meta.key, t)
	
		if((t.keys || !meta.iskey) && t.expand(object, meta.key, t)){
			if(meta.printed.has(object)){
				output += t.format.mapskip
			} else {
				meta.printed.set(object, true)
	
				output += t.format.mapleft
	
				let children = Object.entries(object)
				let len = children.length
				let haschild = len > 0
	
				function printkv(k, v, last){
					let ownpostfix = last ? t.format.lastchild : t.format.child		
					output += '\n' + prefix + ownpostfix + t.format.keyleft + k + t.format.keyright + v
					if(!last){
						output += t.format.separator
					}
				}
	
				let _options = basic.merge({}, options, {
					print: false,
				})
				
				if(haschild){
					children.forEach((e, i) => {
						let last = (len == i+1)
						let childprefix = prefix + (last ? t.format.lastspace : t.format.space)
						
						let skey = __dprint(e[0], _options, {
							printed: meta.printed,
							prefix: childprefix,
							iskey: true,
						})
						
						printkv(
							skey,
							__dprint(e[1], _options, {
								printed: meta.printed,
								prefix: childprefix,
								key: e[1],
							}),
							last
						)
					})
				}
	
				if((closestring && haschild) || (!closestring && meta.iskey)){
					output += '\n' + prefix
				}
				output += t.format.mapright
			}
		}
	
		if(t.print) t.print(output)
		else return output
	}

	__dprint.format = {
		simple: {
			tostring: (v, k, options) => options.expand(v, k, options) ? '' : basic.stringify(v),
			separator: ',',
			keyleft: '[',
			keyright: '] = ',
			mapleft: '{',
			mapright: '}',
			mapskip: '{ ... }',
			space: '  ',
			child: '  ',
			lastchild: '  ',
			lastspace: '  ',
		},
		tree: {
			tostring: basic.stringify,
			separator: '',
			keyleft: '[',
			keyright: ']: ',
			mapleft: '',
			mapright: '',
			mapskip: ' ...',
			child: '|--',
			space: '|  ',
			lastchild: '*--',
			lastspace: '   ',
		},
	}
	
	basic.dprint = __dprint

	basic.subscribe('cl_basis_panorama_module', t => {
		const module = t.module
		if(t.code){
			eval.call({}, t.code)
		}
		basis.moduleReady(module)
	})

	basic.subscribe('cl_basis_panorama_imprt', t => {
		for(let [k, module] of Object.entries(t.imprts)){
			basis.imprt(module)
		}
	})

	basic.dlet(basis.snippetLoader, p => p.IsValid() && p.DeleteAsync(0))
	basis.snippetLoader = $.CreatePanel('Panel', $.GetContextPanel().GetParent(), '')
	basis.snippetLoader.BLoadLayout('file://{resources}/layout/custom_game/basis/snippets.xml', false, false)
	basis.snippetLoader.visible = false

	basis.exprt('basis/basic', basic)

// ------------------------------------------
// setup
// ------------------------------------------

	let setup = basis.imprt('basis/setup', true) || {}

	setup.showLoading = () => {
		if(Game.GameStateIsBefore(DOTA_GameState.DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP)){
			let pickroot = basic.getHud().FindChildTraverse('PreGame')
			pickroot.style.opacity = 0
			basic.onState(DOTA_GameState.DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP, () => {
				pickroot.style.opacity = 1
			})
		}
	}

	setup.setuping = undefined
	setup.errorText = undefined
	
	let setupXML = `
		<Panel id="BasisSetup">
			<Label id="BasisLoading"/>
			<Label id="BasisLoadingError" html="true" allowtextselection="true" acceptsfocus="true"/>
		</Panel>
	`

	let setupCSS = `
		#BasisSetup{
			width: 100%;
			height: 400px;
			vertical-align: center;
			background-color: gradient(linear, 0% 0%, 100% 0%, from(#0002), color-stop(0.2, #0006), color-stop(0.8, #0006), to(#0002));
			opacity: 0;
			transition: opacity 0.3s linear 0s;
		}

		#BasisSetup.Setuping{
			opacity: 1;
		}

		#BasisLoading{
			width: 100%;
			vertical-align: center;
			text-align: center;
			font-size: 60px;
			letter-spacing: 7px;
			color: gradient(linear, 0% 0%, 0% 100%, from(#eee), to(#888));
			text-shadow: 2px 2px 5px 2.0 #000;
			opacity: 1;
		}

		#BasisLoadingError{
			vertical-align: center;
			horizontal-align: center;
			max-height: 100%;
			text-overflow: clip;
			overflow: clip scroll;
			opacity: 0;
			font-size: 20px;
			color: white;
		}

		#BasisSetup.Error #BasisLoading{
			opacity: 0;
		}
		#BasisSetup.Error #BasisLoadingError{
			opacity: 1;
		}
	`

	Object.defineProperty(setup, 'setupCSS', {
		configurable: true,
		enumerable: true,
		get: () => setupCSS,
		set: v => {
			setupCSS = v
			basic.applyCSS(setup.root, v)
		}
	})

	basic.dlet(setup.root, p => p.IsValid() && p.DeleteAsync(0))

	basic.onState(DOTA_GameState.DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP, () => {
		let cuiRoot = $.GetContextPanel().GetParent()
		let csetupRoot = cuiRoot.FindChild('CustomUIContainer_GameSetup').FindChild('CustomUIContainer')
		if(csetupRoot) csetupRoot.style.opacity = 0
		let root = setup.root = basic.createPanels(cuiRoot, setupXML)[0]
		root.FindChild('BasisLoading').text = basic.loc('ui_basis_loading', 'LOADING')
		let lerror = root.FindChild('BasisLoadingError')

		basic.subscribe('cl_basis_setup', t => {
			let issetuping = t.setuping ? true : false
			if(setup.setuping != issetuping){
				root.SetHasClass('Setuping', issetuping)
				if(csetupRoot) csetupRoot.style.opacity = issetuping ? 0 : 1
				setup.setuping = issetuping
			}

			let errorText = (typeof t.setuping == 'string') ? t.setuping : undefined
			if(setup.errorText != errorText){
				if(errorText){
					root.AddClass('Error')
					lerror.text = errorText
				} else {
					root.RemoveClass('Error')
				}
				setup.errorText = errorText
			}

			basic.applyCSS(root, setupCSS)
		})
	})

	basic.afterState(DOTA_GameState.DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP, () => {
		basis.EVENT_KEY = Array.from({length: 32}, () => String.fromCharCode(33 + Math.floor(Math.random() * 90))).join('')
		GameEvents.SendCustomGameEventToServer('sv_basis_setup', {
			event_key: basis.EVENT_KEY,
		})
	})

	basis.exprt('basis/setup', setup)

// ------------------------------------------
// thinker
// ------------------------------------------

	function think(){
		let state = Game.GetState()
		if(_state != state){
			basic.dlet(onStateCallbacks[state], a => a.forEach(f => f()))
			_state = state
		}

		$.Schedule(0, think)
	}
	think()
})();