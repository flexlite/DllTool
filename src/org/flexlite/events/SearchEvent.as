package org.flexlite.events
{
	import flash.events.Event;
	
	
	/**
	 * 搜索事件
	 * @author DOM
	 */
	public class SearchEvent extends Event
	{
		/**
		 * 搜索事件
		 */		
		public static const SEARCH_RES:String = "searchRes";
		/**
		 * 构造函数
		 */		
		public function SearchEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false)
		{
			super(type, bubbles, cancelable);
		}
		/**
		 * 要搜索的键值列表
		 */		
		public var keyList:Array;
	}
}