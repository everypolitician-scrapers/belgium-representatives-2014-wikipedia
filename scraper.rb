#!/bin/env ruby
# frozen_string_literal: true

require 'pry'
require 'scraped'
require 'scraperwiki'
require 'wikidata_ids_decorator'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class MembersPage < Scraped::HTML
  decorator WikidataIdsDecorator::Links

  field :members do
    members_table.xpath('.//tr[td]').map do |tr|
      data = fragment(tr => MemberRow).to_h
      data[:party_id] = parties.find { |p| p[:name] == data[:party] }[:id] rescue ''
      data[:area_id] = areas.find { |p| p[:name] == data[:area] }[:id] rescue ''
      data
    end
  end

  field :parties do
    @parties ||= party_table.xpath('.//tr[td[a]]').map { |tr| fragment(tr => PartyRow).to_h }
  end

  field :areas do
    @areas ||= noko.css('#Zetelverdeling').xpath('following::ul[1]//li').map { |li| fragment(li => AreaLi).to_h }
  end

  private

  def members_table
    noko.xpath('//table[.//th[contains(.,"Kieskring")]]')
  end

  def party_table
    noko.xpath('//table[.//th[contains(.,"Zetels")]]')
  end

  def area_list
    noko.css('#Zetelverdeling').xpath('following::ul[1]//li')
  end
end

class MemberRow < Scraped::HTML
  field :name do
    tds[0].css('a').map(&:text).map(&:tidy).first
  end

  field :id do
    tds[0].css('a/@wikidata').map(&:text).first
  end

  field :party do
    party = tds[1].text.tidy
    return "Ecolo-Groen" if %w(Ecolo Groen).include? party
    party
  end

  field :area do
    tds[2].text.tidy
  end

  private

  def tds
    noko.css('td')
  end
end

class PartyRow < Scraped::HTML
  REMAP = {
    'Ecolo/Groen' => 'Groen'
  }

  field :name do
    name = td.css('a').map(&:text).map(&:tidy).first
    return "Ecolo-Groen" if %w(Ecolo Groen).include? name
    name
  end

  field :id do
    return 'Q19850616' if name == 'Ecolo-Groen'
    td.css('a/@wikidata').map(&:text).first
  end

  private

  def td
    noko.css('td')[1]
  end
end

class AreaLi < Scraped::HTML
  field :name do
    noko.css('a').map(&:text).map(&:tidy).first
  end

  field :id do
    noko.css('a/@wikidata').map(&:text).first
  end
end

url = 'https://nl.wikipedia.org/wiki/Kamer_van_Volksvertegenwoordigers_(samenstelling_2014-2019)'
Scraped::Scraper.new(url => MembersPage).store(:members, index: %i[name party])
