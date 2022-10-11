import SwiftUI
import ValorantAPI
import HandyOperators
import UniformTypeIdentifiers
import Protoquest

struct ClientLogView: View {
	var client: ValorantClient
	@State var log: ClientLog?
	
    var body: some View {
		UnwrappingView(
			value: log,
			placeholder: "Loading Request log…"
		) { log in
			List {
				Text("These are the last \(log.exchanges.count) requests sent by the app, along with their responses.")
					.frame(maxWidth: .infinity, alignment: .leading)
				
				Section("Requests") {
					ForEach(log.exchanges) { exchange in
						NavigationLink {
							ExchangeView(exchange: exchange)
						} label: {
							VStack(spacing: 4) {
								Text(exchange.request.url!.description)
									.frame(maxWidth: .infinity, alignment: .leading)
									.font(.footnote)
								
								HStack(alignment: .lastTextBaseline) {
									Text(exchange.request.httpMethod!)
										.fontWeight(.medium)
									
									Text("\(exchange.response.httpMetadata!.statusCode)")
									
									Spacer()
									
									Text(exchange.time, format: .dateTime)
										.font(.footnote)
								}
								.foregroundColor(.secondary)
							}
							.padding(.vertical, 2)
						}
					}
				}
			}
		}
		.task {
			guard !isInSwiftUIPreview else { return }
			log = await client.getLog()
		}
		.navigationTitle("Request Log")
    }
	
	struct ExchangeView: View {
		var exchange: ClientLog.Exchange
		
		var body: some View {
			Form {
				Section {
					Text(exchange.time, format: .dateTime)
				}
				
				Section("Request") {
					labeledRow("Method", describing: exchange.request.httpMethod!)
					labeledRow("URL", describing: exchange.request.url!)
					
					bodyDetailsView(for: exchange.request.httpBody)
				}
				
				Section("Response") {
					labeledRow("Response Code", describing: exchange.response.httpMetadata!.statusCode)
					
					bodyDetailsView(for: exchange.response.body)
				}
				
				let info = ExchangeInfo(exchange)
				let encodedInfo = try! JSONEncoder().encode(info)
				let infoString = String(bytes: encodedInfo, encoding: .utf8)!
				
				Button {
					UIPasteboard.general.setData(
						encodedInfo,
						forPasteboardType: UTType.json.identifier
					)
				} label: {
					Label("Copy to Clipboard", systemImage: "doc.on.doc")
				}
				
				Link(destination: mailtoLink(body: infoString)) {
					Label("Send to Developer", systemImage: "envelope")
				}
			}
			.navigationTitle("Exchange")
		}
		
		func mailtoLink(body: String) -> URL {
			(URLComponents() <- {
				$0.scheme = "mailto"
				$0.queryItems = [
					.init(name: "to", value: "julian.3kreator@gmail.com"),
					.init(name: "subject", value: "Recon Bolt Exchange"),
					.init(name: "body", value: body),
				]
			})
			.url!
		}
		
		func labeledRow(_ label: LocalizedStringKey, describing value: Any) -> some View {
			labeledRow(label, value: "\(String(describing: value))")
		}
		
		func labeledRow(_ label: LocalizedStringKey, value: LocalizedStringKey) -> some View {
			HStack {
				Text(label)
					.foregroundStyle(.secondary)
				Spacer()
				Text(value)
					.multilineTextAlignment(.trailing)
			}
		}
		
		func bodyDetailsView(for data: Data?) -> some View {
			let body = data ?? .init()
			let string = String(bytes: body, encoding: .utf8)
			return NavigationLink {
				ScrollView {
					Group {
						if let string {
							Text(string)
								.frame(maxWidth: .infinity, alignment: .leading)
						} else {
							Text("<Binary Data>")
								.foregroundStyle(.secondary)
						}
					}
					.padding()
				}
				.navigationTitle("Body")
				.toolbar {
					Button {
						if let string {
							UIPasteboard.general.string = string
						} else {
							UIPasteboard.general.setData(body, forPasteboardType: UTType.data.identifier)
						}
					} label: {
						Label("Copy Body", systemImage: "doc.on.doc")
					}
				}
			} label: {
				labeledRow("Body", value: "\(body.count) bytes" as LocalizedStringKey)
			}
			.disabled(body.isEmpty)
		}
	}
}

struct ExchangeInfo: Encodable {
	var time: Date
	var request: Request
	var response: Response
	
	init(_ exchange: ClientLog.Exchange) {
		time = exchange.time
		request = .init(exchange.request)
		response = .init(exchange.response)
	}
	
	struct Request: Encodable {
		var method: String
		var url: URL
		var headers: [String: String]
		var body: Data
		
		init(_ raw: URLRequest) {
			method = raw.httpMethod!
			url = raw.url!
			headers = raw.allHTTPHeaderFields ?? [:]
			body = raw.httpBody ?? .init()
		}
	}
	
	struct Response: Encodable {
		var statusCode: Int
		var headers: [String: String]
		var body: Data
		
		init(_ raw: Protoresponse) {
			statusCode = raw.httpMetadata!.statusCode
			let rawHeaders = raw.httpMetadata?.allHeaderFields ?? [:]
			headers = .init(uniqueKeysWithValues: rawHeaders.map {
				(String(describing: $0), String(describing: $1))
			})
			body = raw.body
		}
	}
}

#if DEBUG
struct ClientLogView_Previews: PreviewProvider {
    static var previews: some View {
		let url = URL(string: "https://example.com/api/v1/test/stuff")!
		let log = ClientLog() <- {
			$0.logExchange(
				request: .init(url: url) <- {
					$0.httpMethod = "GET"
				},
				response: .init(
					body: Data(),
					metadata: HTTPURLResponse(
						url: url,
						statusCode: 200,
						httpVersion: nil,
						headerFields: nil
					)!,
					decoder: .init()
				)
			)
			$0.logExchange(
				request: .init(url: url) <- {
					$0.httpMethod = "POST"
					$0.httpBody = try! JSONEncoder().encode(APISession.mocked)
				},
				response: .init(
					body: Data(),
					metadata: HTTPURLResponse(
						url: url,
						statusCode: 404,
						httpVersion: nil,
						headerFields: nil
					)!,
					decoder: .init()
				)
			)
		}
		
		NavigationView {
			ClientLogView(client: .mocked, log: log)
		}
		
		NavigationView {
			ClientLogView.ExchangeView(exchange: log.exchanges[1])
		}
		.previewDisplayName("Exchange View")
    }
}
#endif