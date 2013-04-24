package org.flexlite.action
{
	import flash.events.EventDispatcher;
	import flash.filesystem.File;
	import flash.system.Capabilities;
	import flash.utils.ByteArray;
	import flash.utils.Dictionary;
	import flash.utils.getTimer;
	
	import mx.collections.ArrayCollection;
	
	import org.bytearray.explorer.SWFExplorer;
	import org.flexlite.domDisplay.DxrFile;
	import org.flexlite.domDisplay.codec.DxrDecoder;
	import org.flexlite.domDisplay.codec.DxrEncoder;
	import org.flexlite.domUtils.CRC32Util;
	import org.flexlite.domUtils.DomLoader;
	import org.flexlite.domUtils.FileUtil;
	import org.flexlite.domUtils.SharedObjectUtil;
	import org.flexlite.domUtils.StringUtil;
	
	import spark.components.WindowedApplication;
	
	/**
	 * 配置管理器
	 * @author DOM
	 */
	public class ConfigManager extends EventDispatcher
	{
		/**
		 * 构造函数
		 */		
		public function ConfigManager()
		{
			super();
			
			loadGroups = [{name:"loading",list:[]},{name:"preload",list:[]}];
			
			typeDic["swf"] = "swf";
			typeDic["xml"] = "xml";
			typeDic["dxr"] = "dxr";
			typeDic["amf"] = "amf";
			typeDic["json"] = "json";
			typeDic["png"] = "img";
			typeDic["jpg"] = "img";
			typeDic["gif"] = "img";
			typeDic["grp"] = "grp";
			typeDic["txt"] = "txt";
			typeDic["mp3"] = "sound";
			
			filterExtensions = ["fla","as","dxml","mxml"];
		}
		
		public var app:WindowedApplication;
		
		[Bindable]
		/**
		 * 组名列表数据源
		 */		
		public var groupNameData:ArrayCollection = new ArrayCollection();
		
		[Bindable]
		/**
		 * 当前组项列表数据源
		 */		
		public var itemListData:ArrayCollection = new ArrayCollection();
		
		/**
		 * 从目录添加资源时要过滤的文件扩展名列表
		 */
		public var filterExtensions:Array = [];
		/**
		 * 当前配置文件的路径
		 */		
		public var currentConfigPath:String = "";
		/**
		 * 资源相对路径根目录
		 */		
		public var resourcePath:String = "";
		
		private var _currentGroupName:String = "";
		/**
		 * 当前选中的组名
		 */
		public function get currentGroupName():String
		{
			return _currentGroupName;
		}

		public function set currentGroupName(value:String):void
		{
			if(_currentGroupName==value)
				return;
			_currentGroupName = value;
			itemListData.source = getCurrentGroup();
		}
		
		/**
		 * 组列表
		 */		
		private var loadGroups:Array = [];
		/**
		 * 当前资源组的个数
		 */		
		public function get numGroups():int
		{
			return loadGroups.length;
		}
		
		/**
		 * 清空所有配置
		 */		
		public function cleanAll():void
		{
			_hasRepeatKey = false;
			currentConfigPath = "";
			loadGroups = [{name:"loading",list:[]},{name:"preload",list:[]}];
			refreshGroupList();
			itemListData.source = getCurrentGroup();
		}
		/**
		 * 检查指定的组名是否存在
		 */		
		public function hasGroupName(name:String):Boolean
		{
			return groupNameData.source.indexOf(name)!=-1
		}
		/**
		 * 添加一个资源组
		 */		
		public function addOneGroup(group:Object):void
		{
			loadGroups.push(group);
		}
		/**
		 * 获取当前组的数据项列表
		 */
		private function getCurrentGroup():Array
		{
			var group:Array = getGroupByName(currentGroupName);
			if(!group)
				group = [];
			return group;
		}
		/**
		 * 根据组名获取组列表
		 */		
		private function getGroupByName(name:String):Array
		{
			var group:Array;
			for each(var g:Object in loadGroups)
			{
				if(g.name==name)
				{
					if(g.list is Array)
						group = g.list;
					break;
				}
			}
			return group;
		}
		
		/**
		 * 待分析subkeys的文件列表
		 */
		private var subkeyList:Array = [];
		
		/**
		 * 添加文件列表
		 */
		public function addFiles(list:Array):void
		{
			var group:Array = getCurrentGroup();
			var file:File;
			for each(file in list)
			{
				var data:Object = parseFile(file);
				if(isAdded(group,data.url))
					continue;
				group.push(data);
				if(_currentGroupName=="loading")
					continue;
				var type:String = data.type;
				if(type!="dxr"&&type!="swf"&&type!="grp")
					continue;
				data.nativePath = file.url;
				if(subkeyList.indexOf(data)==-1)
					subkeyList.push(data);
			}
			startTime = getTimer();
			app.status = "正在刷新中...";
			nextSubkeyObject();
		}
		/**
		 * 分析下一个文件的subkeys
		 */
		private function nextSubkeyObject():void
		{
			if(subkeyList.length==0)
			{
				itemListData.refresh();
				checkKeyRepeat();
				app.status = "刷新成功! 耗时:"+(getTimer()-startTime)+"ms";
				return;
			}
			var data:Object = subkeyList.shift();
			while(!data.nativePath)
			{
				if(subkeyList.length==0)
				{
					itemListData.refresh();
					checkKeyRepeat();
					app.status = "刷新成功! 耗时:"+(getTimer()-startTime)+"ms";
					return;
				}
				data = subkeyList.shift();
			}
			var path:String = data.nativePath;
			delete data.nativePath;
			if(data.type=="swf")
			{
				DomLoader.loadByteArray(path,function(bytes:ByteArray):void{
					var swf:SWFExplorer = new SWFExplorer();
					var definitions:Array = swf.parse(bytes);
					definitions.sort();
					data.subkeys = definitions.join();
					nextSubkeyObject();
				});
			}
			else if(data.type=="dxr")
			{
				DomLoader.loadByteArray(path,function(bytes:ByteArray):void{
					var file:DxrFile = new DxrFile(bytes);
					var keyList:Vector.<String> = file.getKeyList();
					keyList.sort(sortStrings);
					data.subkeys = keyList.join();
					nextSubkeyObject();
				});
			}
			else
			{
				data.subkeys = getSubkeysFromGrp(path);
				nextSubkeyObject();
			}
		}
		
		private function sortStrings(x:String, y:String):Number
		{ 
			if (x < y)
			{
				return -1;
			}
			else if (x > y)
			{
				return 1;
			}
			else
			{
				return 0;
			}
		}

		/**
		 * 从一个打包好的资源里获取subkeys。
		 */		
		private function getSubkeysFromGrp(path:String):String
		{
			var bytes:ByteArray = FileUtil.openAsByteArray(path);
			try
			{
				bytes.uncompress();
			}
			catch(e:Error){}
			bytes.position = 0;
			bytes.readUTF();
			var data:Object = bytes.readObject();
			var subkeys:Array = [];
			for(var name:String in data)
			{
				subkeys.push(name);
				var item:Object = data[name];
				if(item.subkeys)
					subkeys = subkeys.concat(item.subkeys.split(","));
			}
			subkeys.sort();
			return subkeys.join(",");
		}
		
		/**
		 * 指定url的文件是否已经添加到列表了。
		 */
		private function isAdded(group:Array,url:String):Boolean
		{
			for each(var g:Object in loadGroups)
			{
				for each(var data:Object in g.list)
				{
					if(escapeUrl(data.url)==escapeUrl(url))
						return true;
				}
			}
			return false;
		}
		/**
		 * type缓存字典，查询指定扩展名的类型
		 */
		private var typeDic:Dictionary = new Dictionary();
		/**
		 * 返回资源类型列表
		 */		
		public function get resTypes():Array
		{
			var types:Array = [];
			for each(var type:String in typeDic)
			{
				if(types.indexOf(type)==-1&&type!="grp")
				{
					types.push(type);
				}
			}
			return types;
		}
		/**
		 * 解析一个文件为配置数据对象
		 */
		private function parseFile(file:File):Object
		{
			var data:Object = {language:"all",size:file.size.toString()};
			var name:String = FileUtil.getFileName(file.nativePath);
			data.name = name;
			var index:int = file.nativePath.indexOf(resourcePath);
			if(index==0)
				data.url = file.nativePath.substr(resourcePath.length);
			else
				data.url = file.nativePath;
			if(typeDic[file.extension])
				data.type = typeDic[file.extension];
			else
				data.type = "bin";
			return data;
		}
		
		/**
		 * 刷新组名列表数据源
		 */
		public function refreshGroupList():void
		{
			var source:Array = [];
			for each(var group:Object in loadGroups)
			{
				if(!group.list)
					continue;
				var name:String = group.name;
				if(name&&source.indexOf(name)==-1)
					source.push(name);
			}
			source.sort();
			var index:int = source.indexOf("preload");
			if(index!=-1)
			{
				source.splice(index,1);
				source.splice(0,0,"preload");
			}
			index = source.indexOf("loading");
			if(index!=-1)
			{
				source.splice(index,1);
				source.splice(0,0,"loading");
			}
			
			groupNameData.source = source;
		}
		
		/**
		 * 打开一个Dll配置文件
		 * @param configPath 配置文件路径
		 * @param type 配置文件类型
		 */			
		public function openConfig(configPath:String,type:String):void
		{
			var file:File = File.applicationDirectory.resolvePath(configPath);
			this.currentConfigPath = configPath;
			var data:Object;
			if(type=="JSON"||type=="XML")
			{
				DomLoader.loadText(file.url,function(str:String):void{
					if(type=="JSON")
					{
						try
						{
							data = JSON.parse(str);
						}
						catch(e:Error){}
					}
					else
					{
						try
						{
							data = XML(str);
						}
						catch(e:Error){}
					}
					importConfigObject(data);
				});
			}
			else
			{
				DomLoader.loadByteArray(file.url,function(bytes:ByteArray):void{
					try
					{
						bytes.uncompress();
					}
					catch(e:Error){}
					try
					{
						bytes.position = 0;
						data = bytes.readObject();
					}catch(e:Error){}
					importConfigObject(data);
				});
			}
		}
		
		private function importConfigObject(data:Object):void
		{
			loadGroups.length = 0;
			if(data==null)
			{
				itemListData.refresh();
				return;
			}
			if(data is XML)
			{
				var xmlConfig:XML = data as XML;
				data = {};
				for each(var group:XML in xmlConfig.children())
				{
					var name:String = String(group.@name);
					if(name=="")
						continue;
					var g:Array = getGroupByName(name);
					if(!g)
					{
						g = [];
						var obj:Object = {name:name,list:g};
						loadGroups.push(obj);
					}
					getItemFromXML(group,g);
					
				}
			}
			else
			{
				for(var key:String in data)
				{
					loadGroups.push({name:key,list:data[key]});
				}
			}
			replaceSeparator(true);
			checkKeyRepeat();
			refreshGroupList();
			itemListData.source = getCurrentGroup();
		}
		
		/**
		 * 从xml里解析加载项
		 */		
		private function getItemFromXML(xml:XML,group:Array = null):void
		{
			for each(var item:XML in xml.children())
			{
				var lang:String = String(item.@language);
				var obj:Object = {name:String(item.@name),url:String(item.@url),
					language:String(item.@language),type:String(item.@type),size:String(item.@size)};
				if(item.hasOwnProperty("@subkeys"))
					obj.subkeys = String(item.@subkeys);
				if(group)
					group.push(obj);
			}
		}
		
		
		/**
		 * 解析配置文件
		 */
		public function parseConfig(config:XML):void
		{
			var types:XMLList = config.types.type;
			for each(var type:XML in types)
			{
				var name:String = String(type.@name);
				var exts:Array = String(type.@extensions).split(",");
				for each(var ext:String in exts)
				{
					ext = StringUtil.trim(ext);
					if(ext=="")
						continue;
					typeDic[ext] = name;
				}
			}
			if(config["filters-extensions"])
			{
				var filters:Array = String(config["filters-extensions"][0]).split(",");
				for each(var f:String in filters)
				{
					f = StringUtil.trim(f);
					if(f=="")
						continue;
					filterExtensions.push(f);
				}
			}
		}
		
		/**
		 * 保存配置文件,过滤的文件类型，扩展名映射表。
		 */
		public function saveConfig():void
		{
			var filters:String = filterExtensions.join(",");
			
			var config:String = '<?xml version="1.0" encoding="utf-8"?>\n<config>\n'+
				'	<filters-extensions>'+filters+'</filters-extensions>'+
				'<!-- 定义添加文件时要忽略的扩展名列表 -->\n	<types><!-- 定义每种文件类型对应的扩展名列表 -->\n';
			var extDic:Dictionary = new Dictionary;
			for(var ext:String in typeDic)
			{
				var type:String = typeDic[ext];
				if(extDic[type])
					extDic[type].push(ext);
				else
					extDic[type] = [ext];
			}
			for(var name:String in extDic)
			{
				config+=getTypeItem(name,extDic[name].join(","));
			}
			config += '	</types>\n</config>';
			FileUtil.save("config/config.xml",config);
		}
		
		private function getTypeItem(name:String,ext:String):String
		{
			return '		<type name="'+name+'" extensions="'+ext+'"/>\n';
		}
		
		/**
		 * 根据当期的导出类型生成当前的配置文件对象
		 */
		public function getConfigData(type:String):*
		{
			var oldLoadGroup:Array = loadGroups;
			var bytes:ByteArray = new ByteArray();
			bytes.writeObject(loadGroups);
			bytes.position = 0;
			loadGroups = bytes.readObject();
			cleanSearchAndExist();
			replaceSeparator(false);
			var data:*;
			switch(type)
			{
				case "AMF":
					bytes = new ByteArray();
					bytes.writeObject(getConfigObject());
					bytes.compress();
					data = bytes;
					break;
				case "XML":
					var xml:XML = getConfigXML();
					data = "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n"+xml.toXMLString();
					break;
				case "JSON":
					data = JSON.stringify(getConfigObject());
					break;
			}
			loadGroups = oldLoadGroup;
			return data;
		}
		/**
		 * 搜索并高亮显示指定键值列表
		 * @param keyList 要搜索的键值列表
		 */		
		public function searchKeys(keyList:Array):void
		{
			for each(var group:Object in loadGroups)
			{
				for each(var data:Object in group.list)
				{
					if(keyList.indexOf(data.name)!=-1)
					{
						data.nameSearch = [data.name];
					}
					if(data.subkeys)
					{
						var subkeySearch:Array = [];
						for each(var key:String in data.subkeys.split(","))
						{
							if(keyList.indexOf(key)!=-1&&subkeySearch.indexOf(key)==-1)
								subkeySearch.push(key);
						}
						if(subkeySearch.length>0)
							data.subkeySearch = subkeySearch;
					}
				}
				
			}
			itemListData.refresh();
		}
		/**
		 * 清除搜索和文件是否存在标记
		 * @param cleanExist 是否清理文件存在的标记,默认true。
		 */		
		public function cleanSearchAndExist(cleanExist:Boolean=true):void
		{
			for each(var group:Object in loadGroups)
			{
				for each(var data:Object in group.list)
				{
					if(data.nameSearch)
						delete data.nameSearch;
					if(data.subkeySearch)
						delete data.subkeySearch;
					if(cleanExist&&data.notExists)
						delete data.notExists;
					
				}
			}
			itemListData.refresh();
		}
		/**
		 * 替换url里的斜杠或反斜杠
		 */
		private function replaceSeparator(windowsStyle:Boolean):void
		{
			if(windowsStyle)
			{
				for each(var g:Object in loadGroups)
				{
					doReplace("/",File.separator,g.list);
				}
				
			}
			else
			{
				for each(var group:Object in loadGroups)
				{
					doReplace(File.separator,"/",group.list);
				}
			}
		}
		/**
		 * 转换url中的反斜杠为斜杠
		 */
		public function escapeUrl(url:String):String
		{
			return url?url.split("\\").join("/"):"";
		}
		/**
		 *  执行替换url里的斜杠或反斜杠
		 */
		private function doReplace(p:String,rep:String,group:Array):void
		{
			for each(var data:Object in group)
			{
				data.url = StringUtil.replaceStr(data.url,p,rep);
			}
		}
		
		/**
		 * 获取配置文件数据Object对象
		 */
		private function getConfigObject():Object
		{
			var config:Object = {};
			for each(var g:Object in loadGroups)
			{
				config[g.name] = g.list;
			}
			return config;
		}
		/**
		 * 获取配置文件数据XML对象
		 */
		private function getConfigXML():XML
		{
			var xml:XML = <root/>;
			if(loadGroups.length>0)
			{
				for each(var group:Object in loadGroups)
				{
					var lazyload:XML = <group name={group.name}/>;
					for each(var data:Object in group.list)
					{
						lazyload.appendChild(parseXML(data));
					}
					xml.appendChild(lazyload);
				}
			}
			return xml;
		}
		/**
		 * 把一个Object转换成XML节点
		 */
		private function parseXML(data:Object):XML
		{
			var item:XML = <item name={data.name} url={data.url} type={data.type} language={data.language} size={data.size}/>;
			if(data["subkeys"])
			{
				item.@subkeys = data.subkeys;
			}
			return item;
		}
		
		/**
		 * 资源根路径改变后修改加载项的url属性
		 */
		public function replaceUrl(newPath:String,oldPath:String):void
		{
			for each(var g:Object in loadGroups)
			{
				for each(var data:Object in g.list)
				{
					var url:String = oldPath+data.url;
					
					if(!exists(url))
						url = data.url;
					if(url.indexOf(newPath)==0)
					{
						data.url = url.substring(newPath.length);;
					}
				}
			}
		}
		
		/**
		 * 检查指定的文件或文件夹是否存在
		 */		
		public function exists(path:String):Boolean
		{
			path = escapeUrl(path);
			try
			{
				var file:File = new File(path);
				return file.exists;
			}
			catch(e:Error)
			{
				return false;
			}
			return false;
		}
		
		private var _hasRepeatKey:Boolean = false;
		/**
		 * 含有重名项的标志
		 */
		public function get hasRepeatKey():Boolean
		{
			return _hasRepeatKey;
		}

		/**
		 * 键名缓存字典
		 */
		private var keyMap:Dictionary;
		/**
		 * 检查是否含有重复键名并标记
		 */
		public function checkKeyRepeat():void
		{
			keyMap = new Dictionary();
			_hasRepeatKey = false;
			findKeys();
			for(var key:String in keyMap)
			{
				if(keyMap[key].length>1)
				{
					markRepeat(keyMap[key],key);
				}
			}
			itemListData.refresh();
		}
		/**
		 * 获取所有的键名
		 */
		private function findKeys():void
		{
			for each(var group:Object in loadGroups)
			{
				for each(var data:Object in group.list)
				{
					if(keyMap[data.name])
						keyMap[data.name].push(data);
					else
						keyMap[data.name] = [data];
					if(data.hasOwnProperty("subkeys"))
					{
						var keys:Array = (data.subkeys as String).split(",");
						for each(var key:String in keys)
						{
							if(key=="")
								continue;
							if(keyMap[key])
								keyMap[key].push(data);
							else
								keyMap[key] = [data];
						}
					}
					delete data.nameRepeat;
					delete data.subkeyRepeat;
				}
			}
		}
		/**
		 * 检查列表里的重复项
		 */
		private function markRepeat(list:Array,key:String):void
		{
			var langDic:Dictionary = new Dictionary();
			var hasAll:Boolean = false;
			var data:Object;
			for each(data in list)
			{
				var language:String = data.language;
				if(language=="all")
				{
					hasAll = true;
					break;
				}
				if(langDic[language])
					langDic[language].push(data);
				else
					langDic[language] = [data];
			}
			if(hasAll)
			{
				for each(data in list)
				markOneRepeat(data,key);
			}
			else
			{
				for each(var arr:Array in langDic)
				{
					if(arr.length>1)
					{
						for each(data in arr)
						markOneRepeat(data,key);
					}
				}
			}
		}
		/**
		 * 标记一个重复项
		 */
		private function markOneRepeat(data:Object,key:String):void
		{
			_hasRepeatKey = true;
			if(data.name==key)
			{
				if(data.nameRepeat)
				{
					if(data.nameRepeat.indexOf(key)==-1)
						data.nameRepeat.push(key);
				}
				else
				{
					data.nameRepeat = [key];
				}
			}
			var subkeys:String = data.subkeys;
			if(subkeys)
			{
				var keys:Array = subkeys.split(",");
				if(keys.indexOf(key)!=-1)
				{
					if(data.subkeyRepeat)
					{
						if(data.subkeyRepeat.indexOf(key)==-1)
							data.subkeyRepeat.push(key);
					}
					else
					{
						data.subkeyRepeat = [key];
					}
				}
			}
		}
		
		private const MAX_REPEAT_TIMES:int = 10;
		private var currentRepeatTime:int = 1;
		
		private var removedDxrKey:Dictionary;
		/**
		 * 移除重复Dxr素材
		 */	
		public function removeRepeatDxrs():void
		{
			if(!_hasRepeatKey)
				return;
			if(currentRepeatTime>MAX_REPEAT_TIMES)
			{
				currentRepeatTime = 1;
				return;
			}
			currentRepeatTime++;
			removedDxrKey = new Dictionary();
			for each(var group:Object in loadGroups)
			{
				removeRepeatDxrByGroup(group.list);
			}
			checkKeyRepeat();
			removeRepeatDxrs();
		}
		/**
		 * 移除一个组的重复dxr素材。
		 */		
		private function removeRepeatDxrByGroup(group:Array):void
		{
			for each(var data:Object in group)
			{
				if(data.type!="dxr")
					continue;
				var repeat:Array = data.subkeyRepeat;
				if(!repeat)
					continue;
				var url:String = resourcePath + data.url;
				if(!exists(url))
					url = data.url;
				var bytes:ByteArray = FileUtil.openAsByteArray(url);
				if(!bytes)
					continue;
				bytes.position = 0;
				var keyObject:Object = DxrDecoder.readObject(bytes);
				var keyList:Object = keyObject.keyList;
				if(!keyList)
					continue;
				for each(var subkey:String in repeat)
				{
					if(removedDxrKey[subkey])
						continue;
					removedDxrKey[subkey] = true;
					var subkeys:Array = (data.subkeys as String).split(",");
					var index:int = subkeys.indexOf(subkey);
					subkeys.splice(index,1);
					data.subkeys = subkeys.join(",");
					delete keyList[subkey];
				}
				bytes = DxrEncoder.writeObject(keyObject);
				FileUtil.save(url,bytes);
			}
		}
		
		/**
		 * 删除一个资源组
		 * @param name 要删除的组名
		 */	
		public function deleteGroup(name:String):void
		{
			for(var i:int=0;i<loadGroups.length;i++)
			{
				var g:Object = loadGroups[i];
				if(g.name==name)
				{
					loadGroups.splice(i,1);
					break;
				}
			}
			refreshGroupList();
			itemListData.source = getCurrentGroup();
		}
		
		/**
		 * 刷新单个资源
		 */		
		public function refreshOne(data:Object):void
		{
			var url:String = resourcePath+data.url;
			if(!exists(url))
				url = data.url;
			if(!exists(url))
			{
				data.notExists = true;
				return;
			}
			if(data.notExists)
				delete data.notExists;
			url = escapeUrl(url);
			var file:File = File.applicationDirectory.resolvePath(url);
			data.size = file.size.toString();
			if(_currentGroupName=="loading")
				return;
			var type:String = data.type;
			if(type!="dxr"&&type!="swf"&&type!="grp")
				return;
			data.nativePath = file.url;
			if(subkeyList.indexOf(data)==-1)
			{
				subkeyList.push(data);
				if(subkeyList.length==1)
				{
					startTime = getTimer();
					app.status = "正在刷新中...";
					nextSubkeyObject();
				}
			}
		}
		
		private var startTime:Number = 0;
		/**
		 * 刷新所有数据项，重新读取size，subkey。
		 */
		public function refreshAll():void
		{
			for each(var group:Object in loadGroups)
			{
				for each(var data:Object in group.list)
				{
					var url:String = resourcePath+data.url;
					if(!exists(url))
						url = data.url;
					if(!exists(url))
					{
						data.notExists = true;
						continue;
					}
					if(data.notExists)
						delete data.notExists;
					url = escapeUrl(url);
					var file:File = File.applicationDirectory.resolvePath(url);
					data.size = file.size.toString();
					if(group.name=="loading")
						continue;
					var type:String = data.type;
					if(type!="dxr"&&type!="swf"&&type!="grp")
						continue;
					data.nativePath = file.url;
					if(subkeyList.indexOf(data)==-1)
						subkeyList.push(data);
				}
			}
			startTime = getTimer();
			app.status = "正在刷新中...";
			nextSubkeyObject();
		}
		/**
		 * 资源发布路径
		 */		
		private var exportPath:String;
		/**
		 * 开始打包并发布资源
		 * @param exportPath 要输出资源的目标文件夹
		 * @param packedConfigPath 修改后的Dll配置文件的存放路径
		 * @param compressType 要压缩的文件类型
		 * @param packedGroups 要打包的组名列表
		 * @param exculdeTypes 打包时要排除的文件类型
		 * @param type 要导出的配置文件类型
		 */			
		public function startPack(exportPath:String,packedConfigPath:String,compressType:Array,
								  packedGroups:Array,exculdeTypes:Array,type:String):void
		{
			this.exportPath = exportPath;
			this.compressType = compressType;
			this.exculdeTypes = exculdeTypes;
			for each(var group:Object in loadGroups)
			{
				for each(var data:Object in group.list)
				{
					var url:String = resourcePath+data.url;
					if(!exists(url))
						continue;
					var bytes:ByteArray = FileUtil.openAsByteArray(url);
					if(isCompressType(data.type))
					{
						bytes.compress();
						data.size = bytes.length.toString();
					}
					FileUtil.save(exportPath+data.url,bytes);
				}
			}
			
			var configData:* = mergeGroups(packedGroups,type);
			FileUtil.save(packedConfigPath,configData);
			
			var file:File = File.applicationDirectory.resolvePath(escapeUrl(exportPath));
			file.openWithDefaultApplication();
		}
		
		private var compressType:Array = ["xml","json"];
		
		private function isCompressType(type:String):Boolean
		{
			for each(var t:String in compressType)
			{
				if(t==type)
					return true;
			}
			return false;
		}
		
		/**
		 * 合并一个资源组,返回修改后的配置文件对象
		 */
		private function mergeGroups(groups:Array,type:String):*
		{
			var oldLoadGroup:Array = loadGroups;
			var bytes:ByteArray = new ByteArray();
			bytes.writeObject(loadGroups);
			bytes.position = 0;
			loadGroups = bytes.readObject();
			
			for each(var groupName:String in groups)
			{
				var group:Array = getGroupByName(groupName);
				if(!group)
					continue;
				var langDic:Dictionary = getLanguageList(group);
				for(var lang:String in langDic)
				{
					var list:Array = langDic[lang];
					var groupItem:Object = createGroupItem(list,groupName.toUpperCase(),lang.toUpperCase());
					group.push(groupItem);
				}
			}
			var data:* = getConfigData(type);
			loadGroups = oldLoadGroup;
			return data;
		}
		
		private var exculdeTypes:Array = [];
		/**
		 * 根据语言分类
		 */
		private function getLanguageList(list:Array):Dictionary
		{
			var langDic:Dictionary = new Dictionary();
			for(var i:int=0;i<list.length;i++)
			{
				var data:Object = list[i];
				if(exculdeTypes.indexOf(data.type)!=-1||data.type=="grp")
					continue;
				list.splice(i,1);
				i--;
				var lang:String = data.language;
				if(langDic[lang])
					langDic[lang].push(data);
				else
					langDic[lang] = [data];
			}
			return langDic;
		}
		/**
		 * 生成一个资源组节点
		 */
		private function createGroupItem(list:Array,groupName:String,lang:String):Object
		{
			var group:Object = {type:"grp",language:list[0].language};
			var subkeys:Array = [];
			var data:Object = {};
			for each(var item:Object in list)
			{
				if(!exists(exportPath+item.url))
					continue;
				subkeys.push(item.name);
				if(item.subkeys)
					subkeys.push(item.subkeys);
				data[item.name] = {type:item.type,subkeys:item.subkeys,
					bytes:FileUtil.openAsByteArray(exportPath+item.url)};
				FileUtil.deletePath(exportPath+item.url);
			}
			
			if(subkeys.length>0)
				group.subkeys = subkeys.join(",");
			var bytes:ByteArray = new ByteArray();
			bytes.writeUTF("dll");
			bytes.writeObject(data);
			bytes.compress();
			group.size = bytes.length.toString();
			var suffix:String = CRC32Util.getCRC32(bytes).toString(36).toUpperCase();
			var url:String = FileUtil.getDirectory(list[0].url)+groupName+"__"+lang+"__"+suffix+".grp";
			group.url = url;
			group.name = groupName+"__"+suffix;
			FileUtil.save(exportPath+url,bytes);
			return group;
		}
	}
}