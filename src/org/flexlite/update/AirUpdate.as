package org.flexlite.update
{
	
	import air.update.ApplicationUpdaterUI;
	
	import flash.desktop.NativeApplication;
	import flash.desktop.Updater;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.filesystem.File;
	import flash.utils.ByteArray;

	/**
	 * app更新工具
	 * 	步骤	1:获取本地config文件
	 * 		2:通过config文件中的cfg信息 去服务器拉取最新的config配置文件
	 * 		3:比对serverVersion 和 localVersion 
	 * 			a:不同 就通过config中的app路径 下载最新的app 然后更新
	 * 			b:相同 重写 覆盖本地的config文件
	 *  
	 * 	注意 每次发布新的版本 要修改app.xml中的numberVersion项 update.xml中version项 2值必须一模一样
	 * 		
	 * @author wang
	 * 
	 */	
	public class AirUpdate extends EventDispatcher
	{
		/**
		 * 各种状态的ui 
		 * 你需要写一个ui 实现IAirUpdateUI接口
		 */		
		private var ui:IAirUpdateUI;
		
		/**
		 * 配置文件的地址 
		 */		
		private var localConfigPath:String;
		
		/**
		 * 嗯 就是用这货更新的 
		 */		
		private var updater:Updater;
		
		/**
		 * 重新加载次数 
		 */		
		private var reloadcount:int;
		/**
		 * @param ui
		 * 		自动更新时候出现的提示ui
		 * @param configPath
		 *		配置文件的地址 
		 */		
		public function AirUpdate(ui:IAirUpdateUI = null,configPath:String = null)
		{
			this.ui = ui;
			if(!configPath){
				localConfigPath = File.applicationDirectory.nativePath+"/config/update.xml";
			}else{
				localConfigPath = configPath;
			}
		}
		
		public static function getCurrentAppVersion():String{
			var appUpdater:ApplicationUpdaterUI = new ApplicationUpdaterUI();
			return appUpdater.currentVersion;
		}
		
		/**
		 * 如果发现处理错误 或者加载错误 那么必须给一个默认的地址重新加载 
		 */		
		public function error_action():void{
			//todo 这部分自己写...
			
			if(reloadcount++>5){
				trace("重新加载次数超过5次! 无法更新");
				return;
			}
			
		}
		
		
		private var currentUpdateVO:AirUpdateVO;
		/**
		 * 检测是否需要更新 
		 */		
		public function checkUpdate():void{
			//用flie去读取本地config数据
			var f:File = new File(localConfigPath);
			if(!f.exists /*如果文件不存在*/){
				error_action();
				return;
			}
			
			var xml:XML;
			try{
				//有可能配置文件的格式错误
				xml = XML(OpenFile.openAsTxt(f));
				currentUpdateVO = new AirUpdateVO().decode(xml);
				loadconfig();
			}catch(e:Error){
				//本地配置文件加载错误 只能是找个正确的位置加载了
				error_action();
				return;
			}
		}
		
		/**
		 * 加载配置文件 
		 */		
		private function loadconfig():void{
			var loader:UpdateLoader = new UpdateLoader();
			if(ui){
				ui.loadConfig(true,0,100);
			}
			loader.doLoad(currentUpdateVO.cfg,configProgress,configloadComplete);
		}
		private function configProgress(current:int,total:int):void{
			if(ui){
				ui.loadConfig(true,current,total);
			}
		}
		private function configloadComplete(byte:ByteArray):void{
			if(ui){
				ui.loadConfig(false,100,100);
			}
			if(!byte){
				if(ui){
					ui.showMessage("config文件加载失败");
				}
				return;
			}
			
			
			//配置文件加载成功
			
			var xml:XML;
			try{
				xml = XML(byte.readMultiByte(byte.bytesAvailable,OpenFile.getFileType(byte)));
				var serverupdatevo:AirUpdateVO = new AirUpdateVO().decode(xml);
				var vs:Array = serverupdatevo.version.split(".");
				var curVs:Array = getCurrentAppVersion().split(".");
				var isNew:Boolean = false;
				var index:int=0;
				for each(var v:String in vs)
				{
					if(v>curVs[index])
					{
						isNew = true;
						break;
					}
					else if(v<curVs[index])
					{
						break;
					}
					index++;
				}
				if(isNew){
					//检测到2个版本不一样.开始请求更新
					currentUpdateVO = serverupdatevo;
					if(ui){
						ui.submitUpdate(currentUpdateVO.version,loadapp);
					}else{
						loadapp()
					}
				}
			}catch(e:Error){
				error_action();
				return;
			}
		}
		
		/**
		 * 加载app;
		 * @param flag
		 * 	true 加载
		 * 	false 不加载
		 */		
		public function loadapp(flag:Boolean=true):void{
			if(!flag){
				return;
			}
			var loader:UpdateLoader = new UpdateLoader();
			if(ui){
				ui.loadapp(true,0,100);
			}
			loader.doLoad(currentUpdateVO.app,appProgress,appLoadComplete);
		}
		private function appProgress(current:int,totle:int):void{
			if(ui){
				ui.loadapp(true,current,totle);
			}
		}
		private function appLoadComplete(byte:ByteArray):void{
			if(ui){
				ui.loadapp(false,100,100);
			}
			
			if(!byte){
				if(ui){
					ui.showMessage("app文件加载失败");
				}
				return;
			}
			
			try{
				var f:File = OpenFile.write(byte,File.applicationStorageDirectory.nativePath+"/tempApp.air");
				if(!updater){
					updater = new Updater();
				}
				//更新
				updater.update(f,currentUpdateVO.version);
			}catch(e:Error){
				error_action();
				return;
			}
		}
	}
}

import flash.events.Event;
import flash.events.HTTPStatusEvent;
import flash.events.IOErrorEvent;
import flash.events.ProgressEvent;
import flash.net.URLRequest;
import flash.net.URLStream;
import flash.utils.ByteArray;

class UpdateLoader extends URLStream{
	private var url:String;
	private var progress:Function;
	private var complete:Function;
	
	public var result:ByteArray;
	public function UpdateLoader():void{
	}
	
	public function doLoad(url:String,progress:Function,complete:Function):void{
		this.url = url;
		this.progress = progress;
		this.complete = complete;
		addEventListener(Event.COMPLETE,loaderHandler,false,int.MAX_VALUE);
		addEventListener(IOErrorEvent.IO_ERROR,ioHandler);
		addEventListener(HTTPStatusEvent.HTTP_STATUS,httpHandler);
		addEventListener(ProgressEvent.PROGRESS,progresshandler);
		load(new URLRequest(url));
	}
	
	
	public function dispose():void{
		url = null;
		progress = null;
		complete = null;
		result = null
		removeEventListener(Event.COMPLETE,loaderHandler);
		removeEventListener(IOErrorEvent.IO_ERROR,ioHandler);
		removeEventListener(HTTPStatusEvent.HTTP_STATUS,httpHandler);
		removeEventListener(ProgressEvent.PROGRESS,progresshandler);
	}
	
	private function loaderHandler(event:Event):void{
		result = new ByteArray();
		readBytes(result);
		result.position = 0;
		if(complete!=null){
			complete(result);
		}
		dispose();
	}
	
	private function ioHandler(event:Event):void{
		if(complete!=null){
			complete(null);
		}
	}
	
	private function httpHandler(event:Event):void{
		
	}
	
	private function progresshandler(event:ProgressEvent):void{
		if(progress!=null){
			progress(event.bytesLoaded,event.bytesTotal);
		}
	}
}