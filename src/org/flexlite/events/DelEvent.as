package org.flexlite.events
{
	import flash.events.Event;
	
	
	/**
	 * 删除事件
	 * @author DOM
	 */
	public class DelEvent extends Event
	{
		/**
		 * 删除事件
		 */		
		public static const DELETE:String = "delete";
		/**
		 * 构造函数
		 */		
		public function DelEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false)
		{
			super(type, bubbles, cancelable);
		}
		/**
		 * 要删除项的数据源
		 */		
		public var data:Object;
		/**
		 * 要删除项的索引
		 */		
		public var itemIndex:int;
	}
}