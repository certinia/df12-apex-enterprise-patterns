/**
 * Copyright (c) 2012, FinancialForce.com, inc
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification, 
 *   are permitted provided that the following conditions are met:
 *
 * - Redistributions of source code must retain the above copyright notice, 
 *      this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright notice, 
 *      this list of conditions and the following disclaimer in the documentation 
 *      and/or other materials provided with the distribution.
 * - Neither the name of the FinancialForce.com, inc nor the names of its contributors 
 *      may be used to endorse or promote products derived from this software without 
 *      specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
 *  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES 
 *  OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL 
 *  THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, 
 *  EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 *  OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 *  OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
**/

public virtual with sharing class SObjectDomain
{
	public List<SObject> Records { get; private set;}
	
	public Schema.DescribeSObjectResult SObjectDescribe {get; private set;}
			
	public static ErrorFactory Errors  {get; private set;}
	
	public static TestFactory Test  {get; private set;}
	
	static
	{
		Errors = new ErrorFactory();
		
		Test = new TestFactory();
	}
	
	public SObjectDomain(List<SObject> sObjectList)
	{
		Records = sObjectList;
		
		SObjectDescribe = Records.getSObjectType().getDescribe();
	}
	
	public virtual void applyDefaults() { }
	
	public virtual void validate() { }
	
	public virtual void validate(Map<Id,SObject> existingRecords) 
	{
		validate();
	}
	
    public virtual void beforeInsert() 
    { 
    	applyDefaults(); 
    }
    
    public virtual void beforeUpdate(Map<Id,SObject> existingRecords) { }
    
    public virtual void beforeDelete() { }
    
    public virtual void afterInsert()
    {
    	if(!SObjectDescribe.isCreateable())
    	   throw new DomainException('Permission to create an ' + SObjectDescribe.getName() + ' denied.');
    	   
    	validate(); 
    }
    
    public virtual void afterUpdate(Map<Id,SObject> existingRecords) 
    {
    	if(!SObjectDescribe.isUpdateable())
    	   throw new DomainException('Permission to udpate an ' + SObjectDescribe.getName() + ' denied.');
    	   
    	validate(existingRecords); 
    }
    
    public virtual void afterDelete() 
    {
    	if(!SObjectDescribe.isDeletable())
    	   throw new DomainException('Permission to delete an ' + SObjectDescribe.getName() + ' denied.');
    }	
	
	public interface IConstructable
	{
		SObjectDomain construct(List<SObject> sObjectList);
	}
	
	/**
	 * Method constructs the given Domain class with the current Trigger context 
	 * before calling the applicable override methods such as beforeInsert, beforeUpdate etc.
	 **/
	public static void triggerHandler(Type domainClass)
	{
		String domainClassName = domainClass.getName();
		Type constructableClass = Type.forName(domainClassName+'.Constructor');
		IConstructable constructor = (IConstructable) constructableClass.newInstance();
		if(System.Test.isRunningTest() & Test.Database.hasRecords())
			Test.Database.testTriggerHandler(constructor);
		else
			triggerHandler(constructor);
	}
	
	/**
	 * Calls the applicable override methods such as beforeInsert, beforeUpdate etc. based on Trigger context
	 **/
	private static void triggerHandler(IConstructable domainConstructor)
	{	
		if(Trigger.isBefore)
	    {
	        if(Trigger.isInsert) domainConstructor.construct(Trigger.new).beforeInsert();
	        else if(Trigger.isUpdate) domainConstructor.construct(Trigger.new).beforeUpdate(Trigger.oldMap);
	        else if(Trigger.isDelete) domainConstructor.construct(Trigger.oldMap.values()).beforeDelete();
	    }
	    else
	    {
	        if(Trigger.isInsert) domainConstructor.construct(Trigger.new).afterInsert();
	        else if(Trigger.isUpdate) domainConstructor.construct(Trigger.new).afterUpdate(Trigger.oldMap);
	        else if(Trigger.isDelete) domainConstructor.construct(Trigger.oldMap.values()).afterDelete();
	    }				
	}
	
	public class DomainException extends Exception
	{
	}

	public String error(String message, SObject record)
	{
		return Errors.error(this, message, record);	
	}
	
	public String error(String message, SObject record, SObjectField field)
	{
		return Errors.error(this, message, record, field);	
	}
	
	public class ErrorFactory
	{
		private List<Error> errorList = new List<Error>(); 
		
		private ErrorFactory()
		{
			
		}
		
		public String error(String message, SObject record)
		{
			return error(null, message, record);	
		}

		private String error(SObjectDomain domain, String message, SObject record)
		{
			ObjectError objectError = new ObjectError();
			objectError.domain = domain;
			objectError.message = message;
			objectError.record = record;
			errorList.add(objectError);
			return message;	
		}
		
		public String error(String message, SObject record, SObjectField field)
		{
			return error(null, message, record, field);	
		}

		private String error(SObjectDomain domain, String message, SObject record, SObjectField field)
		{
			FieldError fieldError = new FieldError();
			fieldError.domain = domain;
			fieldError.message = message;
			fieldError.record = record;
			fieldError.field = field;
			errorList.add(fieldError);
			return message;	
		}	
			
		public List<Error> getAll()
		{ 
			return errorList.clone();
		}
		
		public void clearAll()
		{
			errorList.clear();
		}					
	}
	
	public class FieldError extends ObjectError
	{
		public SObjectField field;
		
		private FieldError()
		{		
			
		}
	}
	
	public virtual class ObjectError extends Error
	{
		public SObject record;
		
		private ObjectError()
		{
		
		}
	}
	
	public abstract class Error
	{
		public String message;
		public SObjectDomain domain;
	}
	
	public class TestFactory
	{
		public MockDatabase Database = new MockDatabase();
		 
		private TestFactory()
		{		
			
		}
	}
	
	public class MockDatabase
	{
		private Boolean isInsert = false;
		private Boolean isUpdate = false;
		private Boolean isDelete = false;
		private List<SObject> records = null;
		private Map<Id, SObject> oldRecords = null;
		
		private MockDatabase()
		{
			
		}
			
		private void testTriggerHandler(IConstructable domainConstructor)
		{
			// Before
	        if(isInsert) domainConstructor.construct(records).beforeInsert();
	        else if(isUpdate) domainConstructor.construct(records).beforeUpdate(oldRecords);
	        else if(isDelete) domainConstructor.construct(oldRecords.values()).beforeDelete();
			// After	        
	        if(isInsert) domainConstructor.construct(records).afterInsert();
	        else if(isUpdate) domainConstructor.construct(records).afterUpdate(oldRecords);
	        else if(isDelete) domainConstructor.construct(oldRecords.values()).afterDelete();
		}
		
		public void onInsert(List<SObject> records)
		{
			this.isInsert = true;
			this.records = records;
		}
		
		public void onUpdate(List<SObject> records, Map<Id, SObject> oldRecords)
		{
			this.isUpdate = true;
			this.records = records;
			this.oldRecords = oldRecords;
		}
		
		public void onDelete(Map<Id, SObject> records)
		{
			this.isDelete = true;
			this.oldRecords = records;
		}
		
		public Boolean hasRecords()
		{
			return records!=null;
		}
	}
}