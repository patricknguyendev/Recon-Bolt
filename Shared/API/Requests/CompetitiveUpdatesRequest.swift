import Foundation
import Combine
import HandyOperators

struct CompetitiveUpdatesRequest: GetJSONRequest {
	var url: URL {
		(URLComponents() <- {
			$0.scheme = "https"
			$0.host = "pd.eu.a.pvp.net" // TODO: other regions—if queried in the wrong region, just returns no matches
			$0.path = "/mmr/v1/players/\(userID.uuidString.lowercased())/competitiveupdates"
			$0.queryItems = [
				URLQueryItem(name: "startIndex", value: "\(startIndex)"),
				URLQueryItem(name: "endIndex", value: "\(endIndex)"),
			]
		}).url!
	}
	
	var userID: UUID
	var startIndex = 0
	var endIndex = 20
	
	struct Response: Decodable {
		var version: Int
		var subject: UUID
		var matches: [Match]
		
		private enum CodingKeys: String, CodingKey {
			case version = "Version"
			case subject = "Subject"
			case matches = "Matches"
		}
	}
}

extension Client {
	func getCompetitiveUpdates(userID: UUID, startIndex: Int = 0) -> AnyPublisher<[Match], Error> {
		send(CompetitiveUpdatesRequest(
			userID: userID,
			startIndex: startIndex, endIndex: startIndex + 20
		))
		.map(\.matches)
		.eraseToAnyPublisher()
	}
}