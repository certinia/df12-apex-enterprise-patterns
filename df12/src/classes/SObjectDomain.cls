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
	
	public SObjectDomain(List<SObject> sObjectList)
	{
		Records = sObjectList;
		
		SObjectDescribe = Records.getSObjectType().getDescribe();
	}
	
	public virtual void applyDefaults() { }
		
	public virtual void validate() { }
	
    public virtual void beforeInsert() 
    { 
    	applyDefaults(); 
    }
    
    public virtual void beforeUpdate(Map<Id,SObject> oldSObjectMap) { }
    
    public virtual void beforeDelete() { }
    
    public virtual void afterInsert()
    {
    	if(!SObjectDescribe.isCreateable())
    	   throw new DomainException('Permission to create an ' + SObjectDescribe.getName() + ' denied.');
    	   
    	validate(); 
    }
    
    public virtual void afterUpdate(Map<Id,SObject> oldSObjectMap) 
    {
    	if(!SObjectDescribe.isUpdateable())
    	   throw new DomainException('Permission to udpate an ' + SObjectDescribe.getName() + ' denied.');
    	   
    	validate(); 
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
		if(Trigger.isBefore)
	    {
	        if(Trigger.isInsert) constructor.construct(Trigger.new).beforeInsert();
	        else if(Trigger.isUpdate) constructor.construct(Trigger.new).beforeUpdate(Trigger.oldMap);
	        else if(Trigger.isDelete) constructor.construct(Trigger.oldMap.values()).beforeDelete();
	    }
	    else
	    {
	        if(Trigger.isInsert) constructor.construct(Trigger.new).afterInsert();
	        else if(Trigger.isUpdate) constructor.construct(Trigger.new).afterUpdate(Trigger.oldMap);
	        else if(Trigger.isDelete) constructor.construct(Trigger.oldMap.values()).afterDelete();
	    }		
	}
	
	public class DomainException extends Exception
	{
	}
}