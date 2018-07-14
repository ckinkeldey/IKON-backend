const csv = require('csvtojson')
const path = require('path')
const fs = require('fs-extra')

class Dataloader {
	constructor(config, secrets){
		this.paths = config.data
		this.googleMapsClient = require('@google/maps').createClient({
  			key: secrets.geocoding_API_key,
  			Promise: Promise
			})
		this.file = {}
	}

	async load() {
		for(var key in this.paths) {
			try {
				this.file[key] = await csv({
					delimiter: (key == 'taxonomy')?';':','
					}).fromFile(path.join(__dirname, this.paths[key]))
			}
			catch(reason)
			{
				console.log(reason)
				process.exit()
			}
		}
	}

	_findInTaxonomy(names) {
		const tax = this.file['taxonomy'].find(row => 
					names.some(name => Object.values(row).includes(name)))
		return (tax != undefined)?tax : {
			"Wissenschaftsbereich": "1 a",
			"Fachgebiet": "2 b"
		}
	}

	_findInInstitutions(id) {
		return this.file['institutions']
				   .find(row => row.institution_id == id)
				   .address
				   .replace(new RegExp('\n', 'g'), ',')
	}

	_geocode(loc) {
		return this.googleMapsClient.geocode({address: loc})
				  .asPromise()
				  .then((response) => {
				    return response.json.results[0]['geometry']['location']
				  })
				  .catch((err) => {
				    console.log(err)
				  })
	}

	async _computeEntry(entry) {
		const tax = this._findInTaxonomy(entry.subject_area.split(';'))
		const address = this._findInInstitutions(entry.institution_id)
		const pos = await this._geocode(address)
		return {
				'antragsteller': 'Anonym',
		        'end': entry.funding_end_year,
		        'forschungsbereich': tax['Wissenschaftsbereich'].split(' ')[1],
		        'geldgeber': 'DFG',
		        'hauptthema': tax['Fachgebiet'].split(' ')[1],
		        'id': entry.project_id,
		        'address': address,
		        'pos' : {
		        	'long': pos.lng,
		        	'lat': pos.lat
		        },
		        'kooperationspartner': '',
		        'nebenthemen': entry.participating_subject_areas_full_string
		        				.split(',')
		        				.map(topic => topic.trim())
		        				.filter(topic => topic != ''),
		        'projektleiter': 'Anonym',
		        'start': entry.funding_start_year,
		        'titel': entry.title,
		        'beschreibung': entry.project_abstract,
		        'href': '',
		        'forschungsregion': entry.international_connections
		        				.split(';')
		        				.map(region => region.trim())
		        				.filter(region => region != ''),
		        'synergie': '1'
		}
	}

	transform() {
		if (this.file !== {}) {
			this.file['csv'] = Promise.all(
				this.file['csv']
					.map(async (entry) => {
						return this._computeEntry(entry)
					})
			)
			.then(values => {
				this._save(values)
				return values
			})
		}
	}

	print() {
		if (this.file !== {}) {
			console.log(this.file)
		}
	}

	async _save(values) {
		try {
			await fs.writeJson(path.join(__dirname, this.paths['jsonOut']), values)
			console.log('success!')
		} catch (err) {
			console.error(err)
		}
	}

}

module.exports = Dataloader