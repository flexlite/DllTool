package update
{
	public interface IAirUpdateUI
	{
		/**
		 * 开始加载config 
		 * @param value
		 * 			true : 开始加载
		 * 			false : 加载完毕
		 * @param current 当前加载了多少
		 * @param totle	总共需要加载多少
		 */		
		function loadConfig(value:Boolean,current:int,totle:int):void;
		
		/**
		 * 请求是否需要加载新版本 
		 * @param updateVersion 
		 * 			服务器版本
		 * @param callbackFunction(value:Boolean)
		 * 			@param	value	true:可以下载 false:不可下载
		 */		
		function submitUpdate(updateVersion:String,callbackFunction:Function):void;
		/**
		 * 
		 * @param value
		 * 			true : 开始加载
		 * 			false : 加载完毕
		 * @param current 当前加载了多少
		 * @param totle	总共需要加载多少
		 */		
		function loadapp(value:Boolean,current:int,totle:int):void;
		
		/**
		 * 信息提示
		 * @param str
		 */		
		function showMessage(str:String):void;
	}
}