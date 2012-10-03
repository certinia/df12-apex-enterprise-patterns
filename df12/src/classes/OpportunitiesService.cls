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

global with sharing class OpportunitiesService 
{		
	global static void applyDiscounts(Set<ID> opportunityIds, Decimal discountPercentage)
	{
		// Create unit of work to capture work and commit it under one transaction
		SObjectUnitOfWork uow = new SObjectUnitOfWork(SERVICE_SOBJECTS);
		
		// Query Opportunities and apply discount
		Opportunities opportunities = new Opportunities(
			new OpportunitiesSelector().selectByIdWithProducts(opportunityIds));				
		opportunities.applyDiscount(discountPercentage, uow);
		
		// Commit updates to opportunities		
		uow.commitWork();						
	}
	
	global static List<Id> createInvoices(Set<ID> opportunityIds, Decimal discountPercentage)
	{
		// Create unit of work to capture work and commit it under one transaction
		SObjectUnitOfWork uow = new SObjectUnitOfWork(SERVICE_SOBJECTS);						

		// Query Opportunities
		Opportunities opportunities = new Opportunities(
			new OpportunitiesSelector().selectByIdWithProducts(opportunityIds));		
		
		// Optionally apply discounts as part of invoice creation
		if(discountPercentage!=null && discountPercentage>0)
			opportunities.applyDiscount(discountPercentage, uow);		
		
		// Create Invoices from the given opportunities
		List<Invoice__c> invoices = new List<Invoice__c>();
		for(Opportunity opportunityRecord : (List<Opportunity>) opportunities.Records)		
		{
			Invoice__c invoice = new Invoice__c();
			// TODO: Populate invoice fields ...
			uow.registerNew(invoice);	
		}
		
		// Commit any Opportunity updates and new invoices
		uow.commitWork();									
		
		// Invoice Ids
		List<Id> invoiceIds = new List<Id>();
		for(Invoice__c invoice : invoices)
			invoiceIds.add(invoice.Id);
		return invoiceIds;
	}
	
	// SObject's used by the logic in this service, listed in dependency order
	private static List<Schema.SObjectType> SERVICE_SOBJECTS = 
		new Schema.SObjectType[] { 
			Invoice__c.SObjectType, 
			Opportunity.SObjectType, 
			OpportunityLineItem.SObjectType };	
}