package update
{
	public class AirUpdateVO
	{
		public function AirUpdateVO()
		{
		}
		
		/**
		 * 版本号
		 */		
		public var version:String;
		
		/**
		 * 服务器端配置文件下载地址
		 */		
		public var cfg:String;
		
		/**
		 * 服务器端app文件下载地址
		 */		
		public var app:String;
		
		/**
		 * xml->vo decode不解释 
		 * @param xml
		 * 
		 */		
		public function decode(xml:XML):AirUpdateVO{
			var p:String;
			var xmllist:XMLList = xml.children();
			for each(xml in xmllist){
				p = xml.name();
				if(hasOwnProperty(p)){
					this[p] = xml.children().toString();
				}
			}
			return this;
		}
	}
}